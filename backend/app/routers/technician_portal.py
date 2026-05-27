from datetime import datetime, timedelta
import secrets

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app import models, schemas
from app.services.notification_service import create_notification

router = APIRouter(prefix="/technician", tags=["technician-portal"])
security = HTTPBearer(auto_error=False)


def _get_current_technician(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> models.Technician:
    if not credentials or not credentials.credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing technician access token"
        )

    session = db.query(models.TechnicianAccessSession).options(
        joinedload(models.TechnicianAccessSession.technician)
    ).filter(
        models.TechnicianAccessSession.access_token == credentials.credentials
    ).first()

    if not session:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid technician access token"
        )

    if session.expires_at and session.expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Technician access token expired"
        )

    if not session.technician.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Technician account is inactive"
        )

    return session.technician


@router.post("/access", response_model=schemas.TechnicianAccessResponse)
def technician_access(
    payload: schemas.TechnicianAccessRequest,
    db: Session = Depends(get_db)
):
    tech = db.query(models.Technician).options(
        joinedload(models.Technician.workshop)
    ).filter(
        models.Technician.access_code == payload.code.strip().upper(),
        models.Technician.is_active.is_(True)
    ).first()

    if not tech:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid access code"
        )

    if tech.access_code_expires_at and tech.access_code_expires_at < datetime.utcnow():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Access code expired"
        )

    if tech.name.strip().lower() != payload.name.strip().lower():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Technician name does not match code"
        )

    token = secrets.token_urlsafe(32)
    expires_at = datetime.utcnow() + timedelta(hours=12)

    access_session = models.TechnicianAccessSession(
        technician_id=tech.id,
        access_token=token,
        expires_at=expires_at
    )
    db.add(access_session)
    db.commit()

    return schemas.TechnicianAccessResponse(
        access_token=token,
        technician_id=tech.id,
        technician_name=tech.name,
        workshop_id=tech.workshop_id,
        workshop_name=tech.workshop.name,
        expires_at=expires_at
    )


@router.get("/incidents", response_model=list[schemas.IncidentResponse])
def get_technician_incidents(
    technician: models.Technician = Depends(_get_current_technician),
    db: Session = Depends(get_db)
):
    incidents = db.query(models.Incident).options(
        joinedload(models.Incident.user),
        joinedload(models.Incident.vehicle),
        joinedload(models.Incident.workshop),
        joinedload(models.Incident.technician),
        joinedload(models.Incident.payment)
    ).filter(
        models.Incident.technician_id == technician.id,
        models.Incident.status.in_([
            models.IncidentStatus.ACCEPTED,
            models.IncidentStatus.ASSIGNED,
            models.IncidentStatus.IN_PROGRESS,
            models.IncidentStatus.COMPLETED
        ])
    ).order_by(models.Incident.updated_at.desc()).all()

    return incidents


@router.patch("/incidents/{incident_id}/status", response_model=schemas.IncidentResponse)
def update_technician_incident_status(
    incident_id: int,
    payload: schemas.TechnicianIncidentStatusUpdate,
    technician: models.Technician = Depends(_get_current_technician),
    db: Session = Depends(get_db)
):
    incident = db.query(models.Incident).options(
        joinedload(models.Incident.user),
        joinedload(models.Incident.vehicle),
        joinedload(models.Incident.workshop),
        joinedload(models.Incident.technician),
        joinedload(models.Incident.payment)
    ).filter(
        models.Incident.id == incident_id,
        models.Incident.technician_id == technician.id
    ).first()

    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found for this technician"
        )

    valid_next = {
        models.IncidentStatus.ACCEPTED: [models.IncidentStatus.IN_PROGRESS],
        models.IncidentStatus.ASSIGNED: [models.IncidentStatus.IN_PROGRESS],
        models.IncidentStatus.IN_PROGRESS: [models.IncidentStatus.COMPLETED],
        models.IncidentStatus.COMPLETED: [],
    }

    if payload.status not in [
        models.IncidentStatus.ASSIGNED,
        models.IncidentStatus.IN_PROGRESS,
        models.IncidentStatus.COMPLETED
    ]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Technicians can only use assigned, in_progress or completed"
        )

    if payload.status == incident.status:
        return incident

    if payload.status not in valid_next.get(incident.status, []):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status transition from {incident.status} to {payload.status}"
        )

    incident.status = payload.status
    if payload.status == models.IncidentStatus.IN_PROGRESS and not incident.started_at:
        incident.started_at = datetime.utcnow()
        create_notification(
            db,
            user_id=incident.user_id,
            incident_id=incident.id,
            title="Tu mecanico va en camino",
            message=f"{technician.name} ya va en camino a tu ubicacion.",
            notification_type="technician_on_the_way",
        )
        if incident.workshop:
            create_notification(
                db,
                user_id=incident.workshop.owner_id,
                incident_id=incident.id,
                title="Servicio iniciado",
                message=f"El mecanico {technician.name} inicio el servicio de la emergencia #{incident.id}.",
                notification_type="technician_started_service",
            )

    if payload.status == models.IncidentStatus.COMPLETED and not incident.completed_at:
        incident.completed_at = datetime.utcnow()
        technician.is_available = True
        if incident.workshop:
            create_notification(
                db,
                user_id=incident.workshop.owner_id,
                incident_id=incident.id,
                title="Servicio finalizado",
                message=f"El mecanico {technician.name} finalizo la emergencia #{incident.id}.",
                notification_type="technician_completed_service",
            )

    history = models.IncidentHistory(
        incident_id=incident.id,
        status=incident.status,
        changed_by_user_id=incident.workshop.owner_id if incident.workshop else incident.user_id,
        notes=f"Estado actualizado por técnico {technician.name}"
    )
    db.add(history)

    db.commit()
    db.refresh(incident)
    return incident


@router.get("/incidents/{incident_id}/payment-qr", response_model=schemas.WorkshopPaymentQRResponse)
def get_incident_payment_qr_for_technician(
    incident_id: int,
    technician: models.Technician = Depends(_get_current_technician),
    db: Session = Depends(get_db)
):
    incident = db.query(models.Incident).filter(
        models.Incident.id == incident_id,
        models.Incident.technician_id == technician.id
    ).first()

    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found for this technician"
        )

    if not incident.workshop_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incident does not have an assigned workshop"
        )

    payment_qr = db.query(models.WorkshopPaymentQR).filter(
        models.WorkshopPaymentQR.workshop_id == incident.workshop_id
    ).first()

    if not payment_qr:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Workshop has no configured QR image"
        )

    return payment_qr


@router.post("/payments/confirm", response_model=schemas.PaymentResponse)
def confirm_technician_payment(
    payload: schemas.TechnicianPaymentConfirm,
    technician: models.Technician = Depends(_get_current_technician),
    db: Session = Depends(get_db)
):
    incident = db.query(models.Incident).filter(
        models.Incident.id == payload.incident_id,
        models.Incident.technician_id == technician.id
    ).first()

    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found for this technician"
        )

    if incident.status != models.IncidentStatus.COMPLETED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Payment can only be confirmed when incident is completed"
        )

    if payload.payment_method not in [models.PaymentMethod.CASH, models.PaymentMethod.QR]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Technicians can only confirm CASH or QR payments"
        )

    payment = db.query(models.Payment).filter(
        models.Payment.incident_id == incident.id
    ).first()

    if not payment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Payment record not found for incident"
        )

    payment.payment_method = payload.payment_method
    payment.is_paid = True
    payment.paid_at = datetime.utcnow()
    payment.notes = f"Pago confirmado por técnico {technician.name}"

    incident.payment_method = payload.payment_method

    db.commit()
    db.refresh(payment)
    return payment
