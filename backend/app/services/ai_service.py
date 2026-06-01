"""
AI Service — Google Gemini integration for AutoGo
Provides: audio transcription, image analysis, priority classification, summary generation.
"""
from __future__ import annotations

import base64
import os
import re
from typing import Optional, Dict

try:
    import google.generativeai as genai
    _GENAI_AVAILABLE = True
except Exception:
    # Catch any exception during import (including native extension errors)
    _GENAI_AVAILABLE = False
    genai = None  # type: ignore

# ─── Configuration ─────────────────────────────────────────────────────────────
_GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
_AI_ENABLED_ENV = os.getenv("AI_ENABLED", "false").lower() == "true"

if _GENAI_AVAILABLE and _AI_ENABLED_ENV and _GEMINI_API_KEY:
    genai.configure(api_key=_GEMINI_API_KEY)

# ─── Priority keywords fallback ────────────────────────────────────────────────
_HIGH_KEYWORDS = [
    "accidente", "choque", "fuego", "incendio", "humo", "motor", "frenos", "batería",
    "volcado", "volcadura", "no enciende", "no arranca", "arrancar", "sobrecalentamiento",
    "urgente", "emergencia grave", "herido", "sin frenos", "falla mecánica grave",
    "ruido extraño", "pérdida de control",
]
_LOW_KEYWORDS = [
    "gasolina", "combustible", "tanque vacío", "llave adentro",
    "rayón", "raspón", "faro fundido", "luz", "llanta baja", "aire", "aceite bajo",
]


def _rule_priority(text: str) -> str:
    t = text.lower()
    if any(w in t for w in _HIGH_KEYWORDS):
        return "high"
    if any(w in t for w in _LOW_KEYWORDS):
        return "low"
    return "medium"


def _gemini_model(name: str = "gemini-2.5-flash"):
    if not _GENAI_AVAILABLE or genai is None:
        raise RuntimeError("google-generativeai not installed")
    return genai.GenerativeModel(name)


class AIService:
    def __init__(self) -> None:
        self.enabled = _AI_ENABLED_ENV and _GENAI_AVAILABLE and bool(_GEMINI_API_KEY)

    # ── Audio transcription ────────────────────────────────────────────────────

    async def transcribe_audio(self, audio_bytes: bytes, mime_type: str = "audio/m4a") -> str:
        """Transcribe audio bytes via Gemini and return cleaned text."""
        if not self.enabled:
            return "Transcripción de audio no disponible (IA deshabilitada)"

        try:
            b64 = base64.b64encode(audio_bytes).decode()
            model = _gemini_model()
            response = model.generate_content([
                {
                    "role": "user",
                    "parts": [
                        {
                            "inline_data": {
                                "mime_type": mime_type,
                                "data": b64,
                            }
                        },
                        (
                            "Eres un asistente de emergencias vehiculares. "
                            "Transcribe el audio y redacta una descripción clara y concisa "
                            "del incidente vehicular. Responde SOLO con la descripción en español, "
                            "sin prefijos ni explicaciones extra."
                        ),
                    ],
                }
            ])
            return response.text.strip()
        except Exception as exc:
            return f"[Error transcripción: {exc}]"

    # ── Image analysis ─────────────────────────────────────────────────────────

    async def analyze_image_bytes(self, image_bytes: bytes, mime_type: str = "image/jpeg") -> str:
        """Describe visible vehicle damage/problem from raw image bytes."""
        if not self.enabled:
            return "Análisis de imagen no disponible (IA deshabilitada)"

        try:
            b64 = base64.b64encode(image_bytes).decode()
            model = _gemini_model()
            response = model.generate_content([
                {
                    "role": "user",
                    "parts": [
                        {
                            "inline_data": {
                                "mime_type": mime_type,
                                "data": b64,
                            }
                        },
                        (
                            "Eres un mecánico experto. Analiza la imagen del vehículo y describe "
                            "claramente qué problema o daño se observa, qué parte está afectada "
                            "y qué tan grave parece. Responde SOLO con la descripción técnica "
                            "en español, sin saludos ni prefijos."
                        ),
                    ],
                }
            ])
            return response.text.strip()
        except Exception as exc:
            return f"[Error análisis imagen: {exc}]"

    # ── Priority classification ────────────────────────────────────────────────

    async def classify_priority(self, text: str) -> str:
        """Return 'low', 'medium', or 'high' with Gemini + keyword fallback."""
        if not self.enabled:
            return _rule_priority(text)

        try:
            model = _gemini_model()
            prompt = (
                "Clasifica la prioridad de esta emergencia vehicular. "
                "Responde ÚNICAMENTE con una sola palabra en minúscula: low, medium o high. "
                "Usa high para: accidentes, incendios, sin frenos, vehículo inmovilizado en carretera rápida. "
                "Usa low para: sin gasolina, llave adentro, faro fundido, llanta baja (no en carretera). "
                "Usa medium para todo lo demás.\n\n"
                f"Descripción: {text}"
            )
            response = model.generate_content(prompt)
            raw = response.text.strip().lower()
            match = re.search(r"\b(low|medium|high)\b", raw)
            return match.group(1) if match else _rule_priority(text)
        except Exception:
            return _rule_priority(text)

    # ── Summary generation ─────────────────────────────────────────────────────

    async def generate_final_summary(self, audio_desc: str, image_desc: str) -> str:
        """Combine audio + image descriptions into a unified incident summary."""
        if not self.enabled:
            combined = " | ".join(filter(None, [audio_desc, image_desc]))
            return combined[:300] if combined else "Sin descripción"

        try:
            model = _gemini_model()
            parts = []
            if audio_desc:
                parts.append(f"Descripción por voz: {audio_desc}")
            if image_desc:
                parts.append(f"Análisis de imagen: {image_desc}")
            combined = "\n".join(parts) or "Sin información"

            prompt = (
                "Eres un despachador de emergencias vehiculares. "
                "Redacta un resumen final claro y conciso del incidente "
                "combinando la siguiente información. "
                "Máximo 3 oraciones mencionando tipo de problema, gravedad y contexto. "
                "Responde SOLO con el resumen en español.\n\n"
                f"{combined}"
            )
            response = model.generate_content(prompt)
            return response.text.strip()
        except Exception as exc:
            return audio_desc or image_desc or f"[Error resumen: {exc}]"

    # ── File-based pipeline helpers ────────────────────────────────────────────

    async def process_audio_file(self, audio_bytes: bytes, mime_type: str = "audio/m4a") -> Dict:
        """Transcribe audio and classify priority. Returns {'description', 'priority'}."""
        description = await self.transcribe_audio(audio_bytes, mime_type)
        priority = await self.classify_priority(description)
        return {"description": description, "priority": priority}

    async def process_image_file(self, image_bytes: bytes, mime_type: str = "image/jpeg") -> Dict:
        """Describe image and classify priority. Returns {'description', 'priority'}."""
        description = await self.analyze_image_bytes(image_bytes, mime_type)
        priority = await self.classify_priority(description)
        return {"description": description, "priority": priority}

    # ── Legacy compatibility (used by existing incidents router) ───────────────

    async def classify_incident(self, description: str, image_url: Optional[str] = None) -> Dict:
        priority = await self.classify_priority(description)
        dl = description.lower()
        if any(w in dl for w in ["llanta", "neumático", "ponchadura", "rueda"]):
            cls = "tire"
        elif any(w in dl for w in ["batería", "no enciende", "no arranca"]):
            cls = "battery"
        elif any(w in dl for w in ["motor", "humo", "sobrecalentamiento"]):
            cls = "engine"
        elif any(w in dl for w in ["frenos", "frenado"]):
            cls = "brakes"
        elif any(w in dl for w in ["gasolina", "combustible", "tanque"]):
            cls = "fuel"
        else:
            cls = "general"
        return {"classification": cls, "priority": priority, "confidence": 0.9 if self.enabled else 0.5}

    async def analyze_image(self, image_url: str) -> Dict:
        return {"objects_detected": [], "description": "N/A (URL-based analysis not supported)"}

    async def generate_summary(self, incident_data: Dict) -> str:
        return incident_data.get("description", "")[:200]

    async def process_incident_creation(
        self,
        description: str,
        image_url: Optional[str] = None,
        audio_url: Optional[str] = None,
    ) -> Dict:
        classification_result = await self.classify_incident(description, image_url)
        return {
            "classification": classification_result["classification"],
            "priority": classification_result["priority"],
            "ai_summary": description[:200],
            "confidence": classification_result["confidence"],
        }


# Singleton instance (kept at end for backward compat)
ai_service = AIService()

