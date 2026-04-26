"""
AI Analysis router — processes audio/image with Gemini before incident creation.
Endpoints:
  POST /ai/analyze-audio   → transcribe + priority
  POST /ai/analyze-image   → describe + priority
  POST /ai/create-incident → full pipeline: files + metadata → incident created
"""
from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session, joinedload
from typing import Optional
from datetime import datetime

from app.database import get_db
from app import models, schemas
from app.auth import get_current_active_user
from app.services.ai_service import AIService

router = APIRouter(prefix="/ai", tags=["AI Analysis"])
_ai = AIService()

# ── Mime helpers ───────────────────────────────────────────────────────────────

_AUDIO_MIMES = {
    "m4a": "audio/mp4",
    "mp4": "audio/mp4",
    "aac": "audio/aac",
    "mp3": "audio/mpeg",
    "wav": "audio/wav",
    "ogg": "audio/ogg",
    "webm": "audio/webm",
    "3gp": "audio/3gpp",
}

_IMAGE_MIMES = {
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "png": "image/png",
    "webp": "image/webp",
    "gif": "image/gif",
    "bmp": "image/bmp",
}


def _audio_mime(filename: str) -> str:
    ext = (filename.rsplit(".", 1)[-1] if "." in filename else "m4a").lower()
    return _AUDIO_MIMES.get(ext, "audio/mp4")


def _image_mime(filename: str) -> str:
    ext = (filename.rsplit(".", 1)[-1] if "." in filename else "jpg").lower()
    return _IMAGE_MIMES.get(ext, "image/jpeg")


# ── /ai/analyze-audio ─────────────────────────────────────────────────────────

@router.post("/analyze-audio")
async def analyze_audio(
    audio: UploadFile = File(...),
    current_user: models.User = Depends(get_current_active_user),
):
    """
    Transcribe an audio file via Gemini and return the description + priority.
    Accepts any common audio format (m4a, mp3, wav, ogg, webm, 3gp, aac, mp4).
    """
    if current_user.role not in [models.UserRole.CLIENT]:
        # also allow admin
        if current_user.role != models.UserRole.ADMIN:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Solo clientes pueden analizar audio de emergencias",
            )

    audio_bytes = await audio.read()
    if not audio_bytes:
        raise HTTPException(status_code=400, detail="Archivo de audio vacío")

    mime = _audio_mime(audio.filename or "audio.m4a")
    result = await _ai.process_audio_file(audio_bytes, mime)

    return {
        "description": result["description"],
        "priority": result["priority"],
        "ai_enabled": _ai.enabled,
    }


# ── /ai/analyze-image ─────────────────────────────────────────────────────────

@router.post("/analyze-image")
async def analyze_image(
    image: UploadFile = File(...),
    current_user: models.User = Depends(get_current_active_user),
):
    """
    Analyze an image of a vehicle incident via Gemini.
    Returns description and detected priority.
    """
    image_bytes = await image.read()
    if not image_bytes:
        raise HTTPException(status_code=400, detail="Archivo de imagen vacío")

    mime = _image_mime(image.filename or "photo.jpg")
    result = await _ai.process_image_file(image_bytes, mime)

    return {
        "description": result["description"],
        "priority": result["priority"],
        "ai_enabled": _ai.enabled,
    }


# ── /ai/create-incident ───────────────────────────────────────────────────────

@router.post("/create-incident", response_model=schemas.IncidentResponse, status_code=201)
async def ai_create_incident(
    vehicle_id: int = Form(...),
    location_text: str = Form(""),
    latitude: float = Form(0.0),
    longitude: float = Form(0.0),
    # These arrive pre-processed by the mobile app
    audio_description: str = Form(""),
    image_description: str = Form(""),
    # Manual override (user can edit AI text before submitting)
    final_description: str = Form(""),
    priority: str = Form("medium"),
    audio: Optional[UploadFile] = File(None),
    image: Optional[UploadFile] = File(None),
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db),
):
    """
    Create an incident with AI-generated metadata.

    Flow:
    1. If raw files arrive, process them with Gemini (fallback for server-side processing).
    2. Merge descriptions into a unified summary.
    3. Persist incident with all AI fields populated.
    """
    # ── Re-process files if client chose to send raw bytes ─────────────────────
    effective_audio_desc = audio_description
    effective_image_desc = image_description

    if audio and not audio_description:
        audio_bytes = await audio.read()
        if audio_bytes:
            result = await _ai.process_audio_file(audio_bytes, _audio_mime(audio.filename or "audio.m4a"))
            effective_audio_desc = result["description"]
            if priority == "medium":
                priority = result["priority"]

    if image and not image_description:
        image_bytes = await image.read()
        if image_bytes:
            result = await _ai.process_image_file(image_bytes, _image_mime(image.filename or "photo.jpg"))
            effective_image_desc = result["description"]

    # ── Build final description ────────────────────────────────────────────────
    if final_description.strip():
        description = final_description.strip()
    else:
        parts = [p for p in [effective_audio_desc, effective_image_desc] if p]
        description = " | ".join(parts) if parts else "Sin descripción"

    # ── Generate AI summary ────────────────────────────────────────────────────
    ai_summary = await _ai.generate_final_summary(effective_audio_desc, effective_image_desc)

    # ── Classify priority (override if AI produced better result) ─────────────
    if priority not in ("low", "medium", "high"):
        priority = "medium"

    # map str priority to enum
    priority_map = {
        "low": models.IncidentPriority.LOW,
        "medium": models.IncidentPriority.MEDIUM,
        "high": models.IncidentPriority.HIGH,
    }
    priority_enum = priority_map.get(priority, models.IncidentPriority.MEDIUM)

    # ── Validate vehicle ───────────────────────────────────────────────────────
    vehicle = db.query(models.Vehicle).filter(
        models.Vehicle.id == vehicle_id,
        models.Vehicle.user_id == current_user.id,
    ).first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehículo no encontrado o no te pertenece")

    # ── Build classification ───────────────────────────────────────────────────
    classification_result = await _ai.classify_incident(description)
    classification = classification_result.get("classification", "general")

    # ── Create incident ────────────────────────────────────────────────────────
    db_incident = models.Incident(
        user_id=current_user.id,
        vehicle_id=vehicle_id,
        description=description,
        status=models.IncidentStatus.PENDING,
        priority=priority_enum,
        latitude=latitude if latitude != 0.0 else None,
        longitude=longitude if longitude != 0.0 else None,
        location_text=location_text or None,
        classification=classification,
        ai_summary=ai_summary,
        # store descriptions in existing text fields
        audio_url=effective_audio_desc if effective_audio_desc else None,
        image_url=effective_image_desc if effective_image_desc else None,
    )
    db.add(db_incident)
    db.commit()
    db.refresh(db_incident)

    # ── History entry ──────────────────────────────────────────────────────────
    history = models.IncidentHistory(
        incident_id=db_incident.id,
        status=models.IncidentStatus.PENDING,
        changed_by_user_id=current_user.id,
        notes=f"Emergencia creada con IA Gemini (prioridad: {priority})",
    )
    db.add(history)
    db.commit()

    return db.query(models.Incident).options(
        joinedload(models.Incident.user),
        joinedload(models.Incident.vehicle),
    ).filter(models.Incident.id == db_incident.id).first()
