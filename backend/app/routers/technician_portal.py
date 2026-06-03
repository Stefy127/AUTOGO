from datetime import datetime, timedelta
import secrets
import math

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app import models, schemas
from app.services.notification_service import create_notification
from app.services.google_maps_routes_service import google_maps_routes_service
from app.services.websocket_manager import websocket_manager

router = APIRouter(prefix="/technician", tags=["technician-portal"])
security = HTTPBearer(auto_error=False)


ACTIVE_TRACKING_STATUSES = [
    models.IncidentStatus.ASSIGNED,
    models.IncidentStatus.ACCEPTED,
    models.IncidentStatus.ON_ROUTE,
    models.IncidentStatus.IN_SERVICE,
    models.IncidentStatus.IN_PROGRESS,
]

VALID_STATUS_TRANSITIONS = {
    models.IncidentStatus.ASSIGNED: [models.IncidentStatus.ON_ROUTE, models.IncidentStatus.CANCELLED],
    models.IncidentStatus.ACCEPTED: [models.IncidentStatus.ON_ROUTE, models.IncidentStatus.CANCELLED],
    models.IncidentStatus.ON_ROUTE: [models.IncidentStatus.IN_SERVICE, models.IncidentStatus.CANCELLED],
    models.IncidentStatus.IN_SERVICE: [models.IncidentStatus.COMPLETED, models.IncidentStatus.CANCELLED],
    models.IncidentStatus.IN_PROGRESS: [models.IncidentStatus.COMPLETED, models.IncidentStatus.CANCELLED],
}


def _incident_changed_by_user_id(technician: models.Technician, incident: models.Incident) -> int:
    if technician.user_id is not None:
        return technician.user_id
    if incident.workshop:
        return incident.workshop.owner_id
    return incident.user_id


def _haversine_distance_meters(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    radius = 6371000
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lng2 - lng1)

    a = math.sin(delta_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda / 2) ** 2
    return 2 * radius * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def should_recalculate_eta(
    incident: models.Incident,
    new_latitude: float,
    new_longitude: float,
    db: Session,
) -> bool:
    if incident.status != models.IncidentStatus.ON_ROUTE:
        return False

    if not incident.last_eta_update_at:
        return True

    elapsed_seconds = (datetime.utcnow() - incident.last_eta_update_at).total_seconds()
    if elapsed_seconds >= 30:
        return True

    last_point = db.query(models.IncidentTracking).filter(
        models.IncidentTracking.incident_id == incident.id,
        models.IncidentTracking.estimated_arrival_time.isnot(None)
    ).order_by(models.IncidentTracking.recorded_at.desc(), models.IncidentTracking.id.desc()).first()

    if not last_point:
        return True

    distance_moved = _haversine_distance_meters(
        last_point.latitude,
        last_point.longitude,
        new_latitude,
        new_longitude,
    )
    return distance_moved > 100


def _get_active_incident_for_technician(
    technician: models.Technician,
    db: Session,
) -> models.Incident:
    incident = db.query(models.Incident).filter(
        models.Incident.technician_id == technician.id,
        models.Incident.workshop_id == technician.workshop_id,
        models.Incident.status.in_(ACTIVE_TRACKING_STATUSES)
    ).order_by(models.Incident.updated_at.desc(), models.Incident.id.desc()).first()

    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No active incident found for this technician"
        )

    return incident


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
            models.IncidentStatus.ON_ROUTE,
            models.IncidentStatus.IN_SERVICE,
            models.IncidentStatus.IN_PROGRESS,
            models.IncidentStatus.COMPLETED
        ])
    ).order_by(models.Incident.updated_at.desc()).all()

    return incidents


@router.patch("/incidents/{incident_id}/status", response_model=schemas.IncidentResponse)
async def update_technician_incident_status(
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
        models.Incident.technician_id == technician.id,
        models.Incident.workshop_id == technician.workshop_id
    ).first()

    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found for this technician"
        )

    if incident.status in [models.IncidentStatus.COMPLETED, models.IncidentStatus.CANCELLED]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incident is already finished"
        )

    new_status = models.IncidentStatus(payload.status)

    if new_status not in [
        models.IncidentStatus.ON_ROUTE,
        models.IncidentStatus.IN_SERVICE,
        models.IncidentStatus.COMPLETED,
        models.IncidentStatus.CANCELLED,
    ]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Technicians can only use on_route, in_service, completed or cancelled"
        )

    if new_status == incident.status:
        return incident

    if new_status not in VALID_STATUS_TRANSITIONS.get(incident.status, []):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid status transition from {incident.status} to {new_status}"
        )

    incident.status = new_status
    technician.is_available = new_status in [models.IncidentStatus.COMPLETED, models.IncidentStatus.CANCELLED]

    notification_payload = None

    if new_status == models.IncidentStatus.ON_ROUTE:
        notification_payload = {
            "title": "Técnico en camino",
            "message": "El técnico asignado ya se dirige a tu ubicación.",
            "notification_type": "technician_on_route",
            "ws_message": "El técnico ya va en camino.",
        }
        # Recalculate route and ETA when technician marks incident as on_route
        try:
            origin_lat = None
            origin_lng = None
            # prefer current technician coords
            if technician.current_latitude is not None and technician.current_longitude is not None:
                origin_lat = technician.current_latitude
                origin_lng = technician.current_longitude
            # fallback to technician's workshop coords
            elif technician.workshop and technician.workshop.latitude is not None and technician.workshop.longitude is not None:
                origin_lat = technician.workshop.latitude
                origin_lng = technician.workshop.longitude

            if origin_lat is not None and incident.latitude is not None and incident.longitude is not None:
                try:
                    route_result = google_maps_routes_service.calculate_route(
                        origin_lat,
                        origin_lng,
                        incident.latitude,
                        incident.longitude,
                    )
                    incident.remaining_distance_meters = route_result.get("distance_meters")
                    incident.estimated_arrival_time = route_result.get("duration_seconds")
                    incident.route_polyline = route_result.get("polyline")
                    incident.last_eta_update_at = datetime.utcnow()
                except Exception:
                    # don't block status change on route API failure
                    pass
        except Exception:
            pass
    elif new_status == models.IncidentStatus.IN_SERVICE:
        incident.started_at = datetime.utcnow()
        notification_payload = {
            "title": "Atención iniciada",
            "message": "El técnico inició la atención de tu vehículo.",
            "notification_type": "technician_started_service",
            "ws_message": "El técnico inició la atención.",
        }
    elif new_status == models.IncidentStatus.COMPLETED:
        incident.completed_at = datetime.utcnow()
        notification_payload = {
            "title": "Servicio finalizado",
            "message": "El servicio fue finalizado correctamente.",
            "notification_type": "technician_completed_service",
            "ws_message": "El servicio fue finalizado correctamente.",
        }
    elif new_status == models.IncidentStatus.CANCELLED:
        notification_payload = {
            "title": "Servicio cancelado",
            "message": "El servicio fue cancelado o requiere reasignación.",
            "notification_type": "service_cancelled",
            "ws_message": "El servicio fue cancelado.",
        }

    if notification_payload:
        create_notification(
            db,
            user_id=incident.user_id,
            incident_id=incident.id,
            title=notification_payload["title"],
            message=notification_payload["message"],
            notification_type=notification_payload["notification_type"],
        )

    history = models.IncidentHistory(
        incident_id=incident.id,
        status=incident.status,
        changed_by_user_id=_incident_changed_by_user_id(technician, incident),
        notes=f"Estado actualizado por técnico {technician.name}"
    )
    db.add(history)

    db.commit()
    db.refresh(incident)

    if notification_payload:
        await websocket_manager.broadcast_to_incident(
            incident.id,
            {
                "type": "status_update",
                "incident_id": incident.id,
                "status": incident.status.value,
                "message": notification_payload["ws_message"],
                "estimated_arrival_time": incident.estimated_arrival_time,
                "remaining_distance_meters": incident.remaining_distance_meters,
                "route_polyline": incident.route_polyline,
            },
        )

    return incident


@router.patch("/location")
async def update_technician_location(
    payload: schemas.TechnicianLocationUpdate,
    technician: models.Technician = Depends(_get_current_technician),
    db: Session = Depends(get_db)
):
    incident = _get_active_incident_for_technician(technician, db)

    technician.current_latitude = payload.latitude
    technician.current_longitude = payload.longitude

    remaining_distance_meters = incident.remaining_distance_meters
    estimated_arrival_time = incident.estimated_arrival_time
    route_polyline = incident.route_polyline
    route_warning = None

    if should_recalculate_eta(incident, payload.latitude, payload.longitude, db):
        if incident.latitude is None or incident.longitude is None:
            route_warning = "Incident destination coordinates are unavailable"
        else:
            try:
                route_result = google_maps_routes_service.calculate_route(
                    payload.latitude,
                    payload.longitude,
                    incident.latitude,
                    incident.longitude,
                )
                remaining_distance_meters = route_result.get("distance_meters")
                estimated_arrival_time = route_result.get("duration_seconds")
                route_polyline = route_result.get("polyline")
                incident.remaining_distance_meters = remaining_distance_meters
                incident.estimated_arrival_time = estimated_arrival_time
                incident.route_polyline = route_polyline
                incident.last_eta_update_at = datetime.utcnow()
            except Exception:
                route_warning = "Google Maps Routes API unavailable; keeping last ETA"

    tracking = models.IncidentTracking(
        incident_id=incident.id,
        technician_id=technician.id,
        latitude=payload.latitude,
        longitude=payload.longitude,
        remaining_distance_meters=remaining_distance_meters,
        estimated_arrival_time=estimated_arrival_time,
        status=incident.status,
    )
    db.add(tracking)

    # If ETA is low, create a proximity notification (throttle to avoid spam)
    try:
        if estimated_arrival_time is not None:
            proximity_threshold_seconds = 300  # 5 minutes
            if estimated_arrival_time <= proximity_threshold_seconds:
                last_notif = db.query(models.Notification).filter(
                    models.Notification.incident_id == incident.id,
                    models.Notification.notification_type == 'technician_nearby'
                ).order_by(models.Notification.created_at.desc()).first()

                should_send = False
                if not last_notif:
                    should_send = True
                else:
                    elapsed = (datetime.utcnow() - last_notif.created_at).total_seconds()
                    if elapsed > proximity_threshold_seconds:
                        should_send = True

                if should_send:
                    create_notification(
                        db,
                        user_id=incident.user_id,
                        incident_id=incident.id,
                        title='Tu técnico está cerca',
                        message='El técnico asignado llegará en menos de 5 minutos.',
                        notification_type='technician_nearby',
                    )

    except Exception:
        # Don't block location update on notification failure
        pass

    db.commit()
    db.refresh(incident)

    # Broadcast tracking update
    await websocket_manager.broadcast_to_incident(
        incident.id,
        {
            "type": "tracking_update",
            "incident_id": incident.id,
            "technician_id": technician.id,
            "latitude": payload.latitude,
            "longitude": payload.longitude,
            "remaining_distance_meters": remaining_distance_meters,
            "estimated_arrival_time": estimated_arrival_time,
            "route_polyline": route_polyline,
        },
    )

    # If we just created a proximity notification, also broadcast a notification message
    try:
        if estimated_arrival_time is not None and estimated_arrival_time <= 300:
            await websocket_manager.broadcast_to_incident(
                incident.id,
                {
                    "type": "notification",
                    "incident_id": incident.id,
                    "title": "Tu técnico está cerca",
                    "message": "El técnico asignado llegará en menos de 5 minutos.",
                    "notification_type": "technician_nearby",
                },
            )
    except Exception:
        pass

    return {
        "incident_id": incident.id,
        "technician_id": technician.id,
        "latitude": payload.latitude,
        "longitude": payload.longitude,
        "remaining_distance_meters": remaining_distance_meters,
        "estimated_arrival_time": estimated_arrival_time,
        "route_polyline": route_polyline,
        "warning": route_warning,
    }


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
