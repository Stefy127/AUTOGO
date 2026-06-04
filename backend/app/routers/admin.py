from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime, timedelta

from app.database import get_db
from app.models import (
    User, Workshop, Incident, Payment, IncidentHistory, Technician, Offer,
    UserRole, IncidentStatus, IncidentPriority
)
from app.schemas import (
    WorkshopResponse, IncidentResponse, PaymentResponse, IncidentHistoryResponse,
    AdminUserUpdate, AdminWorkshopUserResponse, AdminWorkshopUserCreate, AdminUserStatusUpdate,
    AdminTechnicianUpdate, AdminTechnicianStatusUpdate, TechnicianResponse,
    WorkshopCreate, WorkshopUpdate, AdminStatsResponse
)
from app.auth import get_current_user
from app.auth import get_password_hash

router = APIRouter(prefix="/admin", tags=["admin"])


def verify_admin(current_user: User):
    """
    Verifica que el usuario sea administrador.
    """
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso"
        )


def _parse_date_range(start_date: str | None, end_date: str | None) -> tuple[datetime | None, datetime | None]:
    parsed_start: datetime | None = None
    parsed_end_exclusive: datetime | None = None

    try:
        if start_date:
            parsed_start = datetime.strptime(start_date, "%Y-%m-%d")
        if end_date:
            parsed_end_exclusive = datetime.strptime(end_date, "%Y-%m-%d") + timedelta(days=1)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Formato de fecha inválido. Usa YYYY-MM-DD"
        )

    return parsed_start, parsed_end_exclusive


def _to_arrival_minutes(raw_value: int | None) -> float | None:
    if raw_value is None:
        return None
    if raw_value > 200:
        return raw_value / 60.0
    return float(raw_value)


# ==================== WORKSHOPS MANAGEMENT ====================

@router.get("/workshops", response_model=List[WorkshopResponse])
async def get_all_workshops(
    skip: int = 0,
    limit: int = 100,
    is_active: Optional[bool] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener todos los talleres registrados.
    Solo administradores.
    """
    verify_admin(current_user)
    
    query = db.query(Workshop)
    
    if is_active is not None:
        query = query.filter(Workshop.is_active == is_active)
    
    workshops = query.offset(skip).limit(limit).all()
    
    return workshops


@router.get("/workshops/{workshop_id}", response_model=WorkshopResponse)
async def get_workshop_by_id(
    workshop_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_admin(current_user)
    workshop = db.query(Workshop).filter(Workshop.id == workshop_id).first()
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Taller no encontrado"
        )
    return workshop


@router.post("/workshops", response_model=WorkshopResponse, status_code=status.HTTP_201_CREATED)
async def create_workshop(
    payload: WorkshopCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_admin(current_user)

    owner = db.query(User).filter(User.id == payload.owner_id).first()
    if not owner:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Owner no encontrado"
        )
    if owner.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="El owner debe tener rol workshop"
        )

    existing = db.query(Workshop).filter(Workshop.owner_id == payload.owner_id).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Este usuario workshop ya tiene un taller asociado"
        )

    workshop = Workshop(
        owner_id=payload.owner_id,
        name=payload.name,
        address=payload.address,
        latitude=payload.latitude,
        longitude=payload.longitude,
        commission_percentage=payload.commission_percentage,
        is_active=payload.is_active
    )
    db.add(workshop)
    db.commit()
    db.refresh(workshop)
    return workshop


@router.put("/workshops/{workshop_id}", response_model=WorkshopResponse)
async def update_workshop_by_admin(
    workshop_id: int,
    payload: WorkshopUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_admin(current_user)
    workshop = db.query(Workshop).filter(Workshop.id == workshop_id).first()
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Taller no encontrado"
        )

    data = payload.dict(exclude_unset=True)
    for field in ["name", "address", "latitude", "longitude", "commission_percentage", "is_active"]:
        if field in data:
            setattr(workshop, field, data[field])

    db.commit()
    db.refresh(workshop)
    return workshop


@router.get("/workshops/{workshop_id}/users", response_model=List[AdminWorkshopUserResponse])
async def get_workshop_users(
    workshop_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_admin(current_user)
    workshop = db.query(Workshop).filter(Workshop.id == workshop_id).first()
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Taller no encontrado"
        )

    result: List[AdminWorkshopUserResponse] = []

    owner = db.query(User).filter(User.id == workshop.owner_id).first()
    if owner:
        result.append(
            AdminWorkshopUserResponse(
                user_id=owner.id,
                full_name=owner.full_name,
                email=owner.email,
                phone=owner.phone,
                role=owner.role,
                relation="owner",
                workshop_id=workshop.id,
                is_active=workshop.is_active
            )
        )

    technicians = db.query(Technician).filter(Technician.workshop_id == workshop.id).all()
    for tech in technicians:
        tech_user = db.query(User).filter(User.id == tech.user_id).first() if tech.user_id else None
        result.append(
            AdminWorkshopUserResponse(
                user_id=tech_user.id if tech_user else None,
                full_name=tech_user.full_name if tech_user else tech.name,
                email=tech_user.email if tech_user else None,
                phone=tech_user.phone if tech_user else tech.phone,
                role=tech_user.role if tech_user else UserRole.TECHNICIAN,
                relation="technician",
                workshop_id=workshop.id,
                technician_id=tech.id,
                is_active=tech.is_active,
                is_available=tech.is_available,
                access_code=tech.access_code
            )
        )

    return result


@router.post("/workshops/{workshop_id}/users", response_model=AdminWorkshopUserResponse, status_code=status.HTTP_201_CREATED)
async def create_workshop_user(
    workshop_id: int,
    payload: AdminWorkshopUserCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_admin(current_user)
    workshop = db.query(Workshop).filter(Workshop.id == workshop_id).first()
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Taller no encontrado"
        )

    if payload.role not in [UserRole.WORKSHOP, UserRole.TECHNICIAN]:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Solo se permite crear usuarios workshop o technician en este módulo"
        )

    exists = db.query(User).filter(User.email == payload.email).first()
    if exists:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El correo ya está en uso"
        )

    if payload.role == UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se permite crear otro owner workshop desde este detalle. Edita el owner actual."
        )

    user = User(
        email=payload.email,
        hashed_password=get_password_hash(payload.password),
        full_name=payload.full_name,
        phone=payload.phone,
        role=payload.role
    )
    db.add(user)
    db.flush()

    technician = Technician(
        workshop_id=workshop.id,
        user_id=user.id,
        name=payload.full_name,
        phone=payload.phone,
        is_active=True,
        is_available=True
    )
    db.add(technician)
    db.commit()
    db.refresh(user)
    db.refresh(technician)

    return AdminWorkshopUserResponse(
        user_id=user.id,
        full_name=user.full_name,
        email=user.email,
        phone=user.phone,
        role=user.role,
        relation="technician",
        workshop_id=workshop.id,
        technician_id=technician.id,
        is_active=technician.is_active
    )


@router.patch("/users/{user_id}/status")
async def update_user_status(
    user_id: int,
    payload: AdminUserStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_admin(current_user)
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )

    if user.role == UserRole.WORKSHOP:
        workshop = db.query(Workshop).filter(Workshop.owner_id == user.id).first()
        if not workshop:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Workshop del usuario no encontrado")
        workshop.is_active = payload.is_active
    elif user.role == UserRole.TECHNICIAN:
        technician = db.query(Technician).filter(Technician.user_id == user.id).first()
        if not technician:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Registro técnico del usuario no encontrado")
        technician.is_active = payload.is_active
        if not payload.is_active:
            technician.is_available = False
    else:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Este módulo solo permite activar/desactivar usuarios workshop/technician"
        )

    db.commit()
    return {"message": "Estado actualizado correctamente", "user_id": user_id, "is_active": payload.is_active}


@router.put("/technicians/{technician_id}", response_model=TechnicianResponse)
async def admin_update_technician(
    technician_id: int,
    payload: AdminTechnicianUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_admin(current_user)
    technician = db.query(Technician).filter(Technician.id == technician_id).first()
    if not technician:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Técnico no encontrado"
        )

    data = payload.dict(exclude_unset=True)
    allowed_fields = {"name", "phone", "is_active", "is_available"}
    for field, value in data.items():
        if field in allowed_fields:
            setattr(technician, field, value)

    if data.get("is_active") is False:
        technician.is_available = False

    db.commit()
    db.refresh(technician)
    return technician


@router.patch("/technicians/{technician_id}/status", response_model=TechnicianResponse)
async def admin_update_technician_status(
    technician_id: int,
    payload: AdminTechnicianStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    verify_admin(current_user)
    technician = db.query(Technician).filter(Technician.id == technician_id).first()
    if not technician:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Técnico no encontrado"
        )

    technician.is_active = payload.is_active
    if not payload.is_active:
        technician.is_available = False

    db.commit()
    db.refresh(technician)
    return technician


@router.patch("/workshops/{workshop_id}/activate")
async def activate_workshop(
    workshop_id: int,
    is_active: bool,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Activar o desactivar un taller.
    Solo administradores.
    """
    verify_admin(current_user)
    
    workshop = db.query(Workshop).filter(Workshop.id == workshop_id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Taller no encontrado"
        )
    
    workshop.is_active = is_active
    db.commit()
    db.refresh(workshop)
    
    return {
        "message": f"Taller {'activado' if is_active else 'desactivado'} exitosamente",
        "workshop_id": workshop_id,
        "is_active": is_active
    }


# ==================== INCIDENTS MANAGEMENT ====================

@router.get("/incidents", response_model=List[IncidentResponse])
async def get_all_incidents(
    skip: int = 0,
    limit: int = 100,
    status: Optional[IncidentStatus] = None,
    priority: Optional[IncidentPriority] = None,
    workshop_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener todos los incidentes con filtros opcionales.
    Solo administradores.
    """
    verify_admin(current_user)
    
    query = db.query(Incident)
    
    if status:
        query = query.filter(Incident.status == status)
    
    if priority:
        query = query.filter(Incident.priority == priority)
    
    if workshop_id:
        query = query.filter(Incident.workshop_id == workshop_id)
    
    incidents = query.offset(skip).limit(limit).all()
    
    return incidents


@router.delete("/incidents/{incident_id}")
async def delete_incident(
    incident_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Eliminar un incidente.
    Solo administradores.
    """
    verify_admin(current_user)
    
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incidente no encontrado"
        )
    
    db.delete(incident)
    db.commit()
    
    return {
        "message": "Incidente eliminado exitosamente",
        "incident_id": incident_id
    }


# ==================== HISTORY ====================

@router.get("/history", response_model=List[IncidentHistoryResponse])
async def get_full_history(
    skip: int = 0,
    limit: int = 100,
    incident_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener historial completo de cambios de todos los incidentes.
    Solo administradores.
    """
    verify_admin(current_user)
    
    query = db.query(IncidentHistory)
    
    if incident_id:
        query = query.filter(IncidentHistory.incident_id == incident_id)
    
    history = query.order_by(IncidentHistory.timestamp.desc()).offset(skip).limit(limit).all()
    
    return history


# ==================== PAYMENTS ====================

@router.get("/payments", response_model=List[PaymentResponse])
async def get_all_payments(
    skip: int = 0,
    limit: int = 100,
    is_paid: Optional[bool] = None,
    workshop_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener todos los pagos con filtros.
    Solo administradores.
    """
    verify_admin(current_user)
    
    query = db.query(Payment)
    
    if is_paid is not None:
        query = query.filter(Payment.is_paid == is_paid)
    
    if workshop_id:
        # Filtrar pagos por taller
        incident_ids = db.query(Incident.id).filter(Incident.workshop_id == workshop_id).all()
        incident_ids = [i[0] for i in incident_ids]
        query = query.filter(Payment.incident_id.in_(incident_ids))
    
    payments = query.offset(skip).limit(limit).all()
    
    return payments


@router.get("/payments/commissions")
async def get_commissions_report(
    workshop_id: Optional[int] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener reporte de comisiones.
    Solo administradores.
    """
    verify_admin(current_user)
    
    query = db.query(Payment)
    
    if workshop_id:
        incident_ids = db.query(Incident.id).filter(Incident.workshop_id == workshop_id).all()
        incident_ids = [i[0] for i in incident_ids]
        query = query.filter(Payment.incident_id.in_(incident_ids))
    
    if start_date:
        query = query.filter(Payment.created_at >= start_date)
    
    if end_date:
        query = query.filter(Payment.created_at <= end_date)
    
    payments = query.all()
    
    # Calcular totales
    total_payments = sum([float(p.amount) for p in payments])
    total_commissions = sum([float(p.commission_amount) for p in payments])
    total_workshop_earnings = sum([float(p.workshop_earnings) for p in payments])
    
    paid_payments = [p for p in payments if p.is_paid]
    total_paid = sum([float(p.amount) for p in paid_payments])
    total_paid_commissions = sum([float(p.commission_amount) for p in paid_payments])
    
    pending_payments = [p for p in payments if not p.is_paid]
    total_pending = sum([float(p.amount) for p in pending_payments])
    total_pending_commissions = sum([float(p.commission_amount) for p in pending_payments])
    
    return {
        "total_payments_count": len(payments),
        "total_payments_amount": total_payments,
        "total_commissions": total_commissions,
        "total_workshop_earnings": total_workshop_earnings,
        "paid_payments_count": len(paid_payments),
        "paid_amount": total_paid,
        "paid_commissions": total_paid_commissions,
        "pending_payments_count": len(pending_payments),
        "pending_amount": total_pending,
        "pending_commissions": total_pending_commissions
    }


# ==================== STATISTICS ====================

@router.get("/stats", response_model=AdminStatsResponse)
async def get_platform_stats(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    workshop_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener estadísticas globales de la plataforma.
    Solo administradores.
    """
    verify_admin(current_user)
    
    parsed_start, parsed_end_exclusive = _parse_date_range(start_date, end_date)

    incidents_query = db.query(Incident)
    if workshop_id is not None:
        incidents_query = incidents_query.filter(Incident.workshop_id == workshop_id)
    if parsed_start is not None:
        incidents_query = incidents_query.filter(Incident.created_at >= parsed_start)
    if parsed_end_exclusive is not None:
        incidents_query = incidents_query.filter(Incident.created_at < parsed_end_exclusive)
    incidents = incidents_query.all()

    offers_query = db.query(Offer)
    if workshop_id is not None:
        offers_query = offers_query.filter(Offer.workshop_id == workshop_id)
    if parsed_start is not None:
        offers_query = offers_query.filter(Offer.created_at >= parsed_start)
    if parsed_end_exclusive is not None:
        offers_query = offers_query.filter(Offer.created_at < parsed_end_exclusive)
    offers = offers_query.all()

    payments_query = db.query(Payment)
    if workshop_id is not None:
        payments_query = payments_query.join(Incident, Payment.incident_id == Incident.id).filter(Incident.workshop_id == workshop_id)
    if parsed_start is not None:
        payments_query = payments_query.filter(Payment.created_at >= parsed_start)
    if parsed_end_exclusive is not None:
        payments_query = payments_query.filter(Payment.created_at < parsed_end_exclusive)
    payments = payments_query.all()

    incidents_by_status = {status.value: 0 for status in IncidentStatus}
    for incident in incidents:
        incidents_by_status[incident.status.value] = incidents_by_status.get(incident.status.value, 0) + 1

    total_incidents = len(incidents)
    completed_incidents = sum(1 for i in incidents if i.status == IncidentStatus.COMPLETED)
    cancelled_incidents = sum(1 for i in incidents if i.status == IncidentStatus.CANCELLED)
    active_incidents = sum(1 for i in incidents if i.status not in [IncidentStatus.COMPLETED, IncidentStatus.CANCELLED])

    if workshop_id is not None:
        workshop = db.query(Workshop).filter(Workshop.id == workshop_id).first()
        total_workshops = 1 if workshop else 0
        active_workshops = 1 if workshop and workshop.is_active else 0
        inactive_workshops = 1 if workshop and not workshop.is_active else 0
    else:
        total_workshops = db.query(Workshop).count()
        active_workshops = db.query(Workshop).filter(Workshop.is_active == True).count()
        inactive_workshops = max(total_workshops - active_workshops, 0)

    technicians_query = db.query(Technician)
    if workshop_id is not None:
        technicians_query = technicians_query.filter(Technician.workshop_id == workshop_id)
    technicians_rows = technicians_query.all()
    total_technicians = len(technicians_rows)
    available_technicians = sum(1 for t in technicians_rows if t.is_available)
    busy_technicians = max(total_technicians - available_technicians, 0)

    total_offers = len(offers)
    accepted_offers = sum(1 for o in offers if o.status.value == "accepted")
    rejected_offers = sum(1 for o in offers if o.status.value == "rejected")
    pending_offers = sum(1 for o in offers if o.status.value == "pending")

    paid_payments = sum(1 for p in payments if p.is_paid or (p.payment_status or "").lower() == "paid")
    pending_payments = sum(1 for p in payments if (not p.is_paid) or (p.payment_status or "").lower() == "pending")
    pending_verification_payments = sum(
        1 for p in payments if (p.payment_status or "").lower() == "pending_verification"
    )
    cancellation_payments_pending = sum(
        1
        for p in payments
        if (p.payment_type or "").lower() in ["cancellation_on_route", "cancellation_in_service"]
        and (p.payment_status or "").lower() in ["pending", "pending_verification"]
    )

    paid_payments_rows = [
        p for p in payments
        if p.is_paid or (p.payment_status or "").lower() == "paid"
    ]
    total_revenue_usd = float(sum(float(p.amount or 0) for p in paid_payments_rows))
    total_revenue_bob = float(sum(float(p.amount_bob or 0) for p in paid_payments_rows if p.amount_bob is not None))
    platform_commission_usd = float(sum(float(p.commission_amount or 0) for p in paid_payments_rows))
    workshop_earnings_usd = float(sum(float(p.workshop_earnings or 0) for p in paid_payments_rows))

    assignment_minutes_values = [
        (i.accepted_at - i.created_at).total_seconds() / 60.0
        for i in incidents
        if i.accepted_at is not None
    ]
    average_assignment_time_minutes = (
        round(sum(assignment_minutes_values) / len(assignment_minutes_values), 2)
        if assignment_minutes_values else 0.0
    )

    arrival_minutes_values = [
        _to_arrival_minutes(i.estimated_arrival_time)
        for i in incidents
        if _to_arrival_minutes(i.estimated_arrival_time) is not None
    ]
    average_arrival_time_minutes = (
        round(sum(arrival_minutes_values) / len(arrival_minutes_values), 2)
        if arrival_minutes_values else 0.0
    )

    service_minutes_values = [
        (i.completed_at - i.started_at).total_seconds() / 60.0
        for i in incidents
        if i.started_at is not None and i.completed_at is not None
    ]
    average_service_time_minutes = (
        round(sum(service_minutes_values) / len(service_minutes_values), 2)
        if service_minutes_values else 0.0
    )

    total_users = db.query(User).count()
    clients = db.query(User).filter(User.role == UserRole.CLIENT).count()
    workshop_users = db.query(User).filter(User.role == UserRole.WORKSHOP).count()
    technician_users = db.query(User).filter(User.role == UserRole.TECHNICIAN).count()
    admins = db.query(User).filter(User.role == UserRole.ADMIN).count()

    return AdminStatsResponse(
        total_incidents=total_incidents,
        active_incidents=active_incidents,
        completed_incidents=completed_incidents,
        cancelled_incidents=cancelled_incidents,
        incidents_by_status=incidents_by_status,
        total_workshops=total_workshops,
        active_workshops=active_workshops,
        inactive_workshops=inactive_workshops,
        total_technicians=total_technicians,
        available_technicians=available_technicians,
        busy_technicians=busy_technicians,
        total_offers=total_offers,
        accepted_offers=accepted_offers,
        rejected_offers=rejected_offers,
        pending_offers=pending_offers,
        paid_payments=paid_payments,
        pending_payments=pending_payments,
        pending_verification_payments=pending_verification_payments,
        cancellation_payments_pending=cancellation_payments_pending,
        total_revenue_usd=total_revenue_usd,
        total_revenue_bob=total_revenue_bob,
        platform_commission_usd=platform_commission_usd,
        workshop_earnings_usd=workshop_earnings_usd,
        average_assignment_time_minutes=average_assignment_time_minutes,
        average_arrival_time_minutes=average_arrival_time_minutes,
        average_service_time_minutes=average_service_time_minutes,
        users={
            "total": total_users,
            "clients": clients,
            "workshops": workshop_users,
            "technicians": technician_users,
            "admins": admins,
        },
        workshops={
            "total": total_workshops,
            "active": active_workshops,
            "inactive": inactive_workshops,
        },
        technicians={
            "total": total_technicians,
            "available": available_technicians,
            "busy": busy_technicians,
        },
        incidents={
            "total": total_incidents,
            "by_status": incidents_by_status,
        },
        payments={
            "paid": paid_payments,
            "pending": pending_payments,
            "pending_verification": pending_verification_payments,
            "total_revenue": total_revenue_usd,
            "total_commissions": platform_commission_usd,
            "total_workshop_earnings": workshop_earnings_usd,
        },
    )


# ==================== USERS MANAGEMENT ====================

@router.get("/users")
async def get_all_users(
    skip: int = 0,
    limit: int = 100,
    role: Optional[UserRole] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener todos los usuarios con filtros.
    Solo administradores.
    """
    verify_admin(current_user)
    
    query = db.query(User)
    
    if role:
        query = query.filter(User.role == role)
    
    users = query.offset(skip).limit(limit).all()
    
    # No retornar las contraseñas
    result = []
    for user in users:
        user_dict = {
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name,
            "phone": user.phone,
            "role": user.role,
            "created_at": user.created_at,
            "updated_at": user.updated_at
        }
        result.append(user_dict)
    
    return result


@router.delete("/users/{user_id}")
async def delete_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Eliminar un usuario.
    Solo administradores (y no pueden eliminarse a sí mismos).
    """
    verify_admin(current_user)
    
    if user_id == current_user.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No puedes eliminar tu propia cuenta"
        )
    
    user = db.query(User).filter(User.id == user_id).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )
    
    db.delete(user)
    db.commit()
    
    return {
        "message": "Usuario eliminado exitosamente",
        "user_id": user_id
    }


@router.patch("/users/{user_id}")
async def update_user(
    user_id: int,
    user_data: AdminUserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Editar datos de un usuario.
    Solo administradores.
    """
    verify_admin(current_user)

    user = db.query(User).filter(User.id == user_id).first()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Usuario no encontrado"
        )

    update_data = user_data.dict(exclude_unset=True)

    if "email" in update_data:
        existing = db.query(User).filter(User.email == update_data["email"], User.id != user_id).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="El correo ya está en uso"
            )

    for field, value in update_data.items():
        setattr(user, field, value)

    db.commit()
    db.refresh(user)

    return {
        "message": "Usuario actualizado exitosamente",
        "user": {
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name,
            "phone": user.phone,
            "role": user.role,
            "created_at": user.created_at,
            "updated_at": user.updated_at
        }
    }
