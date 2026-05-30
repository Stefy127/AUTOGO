from datetime import date, datetime, time
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

from app.auth import get_current_user
from app.database import get_db
from app.models import (
    Incident,
    IncidentStatus,
    Payment,
    PaymentMethod,
    Technician,
    User,
    UserRole,
    Workshop,
)
from app.schemas import (
    OperationalReportAppliedFilters,
    OperationalReportItem,
    OperationalReportRequest,
    OperationalReportResponse,
    OperationalReportSummary,
)

router = APIRouter(prefix="/reports", tags=["reports"])


def _to_datetime_range_start(value: Optional[date | datetime]) -> Optional[datetime]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    return datetime.combine(value, time.min)


def _to_datetime_range_end(value: Optional[date | datetime]) -> Optional[datetime]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value
    return datetime.combine(value, time.max)


def _parse_incident_status(value: Optional[str]) -> Optional[IncidentStatus]:
    if not value:
        return None
    normalized = value.strip().lower()
    for candidate in IncidentStatus:
        if candidate.value == normalized:
            return candidate
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail="status inválido para el reporte operacional",
    )


def _parse_payment_method(value: Optional[str]) -> Optional[PaymentMethod]:
    if not value:
        return None
    normalized = value.strip().lower()
    for candidate in PaymentMethod:
        if candidate.value == normalized:
            return candidate
    raise HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        detail="payment_method inválido para el reporte operacional",
    )


@router.post("/operational/query", response_model=OperationalReportResponse)
def query_operational_report(
    payload: OperationalReportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    allowed_roles = {UserRole.ADMIN, UserRole.WORKSHOP, UserRole.CLIENT}
    if current_user.role not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tu rol no tiene acceso a reportes operacionales",
        )

    query = db.query(Incident).options(
        joinedload(Incident.user),
        joinedload(Incident.vehicle),
        joinedload(Incident.workshop),
        joinedload(Incident.technician),
        joinedload(Incident.payment),
    )

    role_scope = current_user.role.value
    workshop: Optional[Workshop] = None

    if current_user.role == UserRole.WORKSHOP:
        workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
        if not workshop:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No se encontró un taller asociado al usuario",
            )
        query = query.filter(Incident.workshop_id == workshop.id)
    elif current_user.role == UserRole.CLIENT:
        query = query.filter(Incident.user_id == current_user.id)

    start_dt = _to_datetime_range_start(payload.start_date)
    end_dt = _to_datetime_range_end(payload.end_date)
    if start_dt:
        query = query.filter(Incident.created_at >= start_dt)
    if end_dt:
        query = query.filter(Incident.created_at <= end_dt)

    if payload.incident_type:
        query = query.filter(Incident.classification == payload.incident_type.strip())

    parsed_status = _parse_incident_status(payload.status)
    if parsed_status:
        query = query.filter(Incident.status == parsed_status)

    if payload.technician_id is not None:
        query = query.filter(Incident.technician_id == payload.technician_id)

    if payload.payment_method:
        parsed_payment_method = _parse_payment_method(payload.payment_method)
        query = query.join(Payment, Incident.id == Payment.incident_id).filter(
            Payment.payment_method == parsed_payment_method
        )

    if current_user.role == UserRole.ADMIN:
        if payload.workshop_id is not None:
            query = query.filter(Incident.workshop_id == payload.workshop_id)
        if payload.client_id is not None:
            query = query.filter(Incident.user_id == payload.client_id)
        if payload.vehicle_id is not None:
            query = query.filter(Incident.vehicle_id == payload.vehicle_id)
    elif current_user.role == UserRole.WORKSHOP:
        if payload.technician_id is not None:
            technician = db.query(Technician).filter(
                Technician.id == payload.technician_id,
                Technician.workshop_id == workshop.id,
            ).first()
            if not technician:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="El técnico no pertenece a tu taller",
                )
    elif current_user.role == UserRole.CLIENT and payload.vehicle_id is not None:
        query = query.filter(Incident.vehicle_id == payload.vehicle_id)

    incidents = query.order_by(Incident.created_at.desc(), Incident.id.desc()).all()

    counts = {status.value: 0 for status in IncidentStatus}
    total_amount = 0.0
    total_workshop_earnings = 0.0
    total_paid = 0
    total_unpaid = 0
    items: list[OperationalReportItem] = []

    for incident in incidents:
        counts[incident.status.value] += 1

        payment = incident.payment
        if payment:
            total_amount += float(payment.amount)
            total_workshop_earnings += float(payment.workshop_earnings)
            if payment.is_paid:
                total_paid += 1
            else:
                total_unpaid += 1

        items.append(
            OperationalReportItem(
                incident_id=incident.id,
                created_at=incident.created_at,
                updated_at=incident.updated_at,
                completed_at=incident.completed_at,
                status=incident.status,
                priority=incident.priority,
                classification=incident.classification or "Sin clasificar",
                description=incident.description,
                location_text=incident.location_text,
                client_id=incident.user_id,
                client_name=incident.user.full_name if incident.user else None,
                client_email=incident.user.email if incident.user else None,
                vehicle_id=incident.vehicle_id,
                vehicle_brand=incident.vehicle.brand if incident.vehicle else None,
                vehicle_model=incident.vehicle.model if incident.vehicle else None,
                vehicle_plate=incident.vehicle.plate if incident.vehicle else None,
                workshop_id=incident.workshop_id,
                workshop_name=incident.workshop.name if incident.workshop else None,
                technician_id=incident.technician_id,
                technician_name=incident.technician.name if incident.technician else None,
                payment_id=payment.id if payment else None,
                payment_amount=float(payment.amount) if payment else None,
                payment_method=payment.payment_method if payment else None,
                payment_is_paid=payment.is_paid if payment else None,
                commission_amount=float(payment.commission_amount) if payment else None,
                workshop_earnings=float(payment.workshop_earnings) if payment else None,
            )
        )

    summary = OperationalReportSummary(
        total_incidents=len(incidents),
        pending=counts[IncidentStatus.PENDING.value],
        waiting_offers=counts[IncidentStatus.WAITING_OFFERS.value],
        assigned=counts[IncidentStatus.ASSIGNED.value],
        accepted=counts[IncidentStatus.ACCEPTED.value],
        in_progress=counts[IncidentStatus.IN_PROGRESS.value],
        completed=counts[IncidentStatus.COMPLETED.value],
        cancelled=counts[IncidentStatus.CANCELLED.value],
        total_amount=total_amount,
        total_workshop_earnings=total_workshop_earnings,
        total_paid=total_paid,
        total_unpaid=total_unpaid,
    )

    applied_filters = OperationalReportAppliedFilters(
        start_date=start_dt.isoformat() if start_dt else None,
        end_date=end_dt.isoformat() if end_dt else None,
        workshop_id=payload.workshop_id if current_user.role == UserRole.ADMIN else (workshop.id if workshop else None),
        incident_type=payload.incident_type.strip() if payload.incident_type else None,
        status=parsed_status.value if parsed_status else None,
        technician_id=payload.technician_id,
        client_id=payload.client_id if current_user.role == UserRole.ADMIN else None,
        vehicle_id=payload.vehicle_id if current_user.role in [UserRole.ADMIN, UserRole.CLIENT] else None,
        payment_method=payload.payment_method.strip().lower() if payload.payment_method else None,
    )

    return OperationalReportResponse(
        role_scope=role_scope,
        applied_filters=applied_filters,
        summary=summary,
        items=items,
    )
