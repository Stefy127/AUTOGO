from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Optional
from datetime import datetime, timedelta

from app.database import get_db
from app.models import (
    User, Workshop, Incident, Payment, IncidentHistory, Technician,
    UserRole, IncidentStatus, IncidentPriority
)
from app.schemas import (
    WorkshopResponse, IncidentResponse, PaymentResponse, IncidentHistoryResponse,
    AdminUserUpdate, AdminWorkshopUserResponse, AdminWorkshopUserCreate, AdminUserStatusUpdate,
    AdminTechnicianUpdate, AdminTechnicianStatusUpdate, TechnicianResponse,
    WorkshopCreate, WorkshopUpdate
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

@router.get("/stats")
async def get_platform_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener estadísticas globales de la plataforma.
    Solo administradores.
    """
    verify_admin(current_user)
    
    # Contar usuarios por rol
    total_users = db.query(User).count()
    clients = db.query(User).filter(User.role == UserRole.CLIENT).count()
    workshops = db.query(User).filter(User.role == UserRole.WORKSHOP).count()
    technicians = db.query(User).filter(User.role == UserRole.TECHNICIAN).count()
    admins = db.query(User).filter(User.role == UserRole.ADMIN).count()
    
    # Contar talleres
    total_workshops = db.query(Workshop).count()
    active_workshops = db.query(Workshop).filter(Workshop.is_active == True).count()
    
    # Contar técnicos
    total_technicians = db.query(Technician).count()
    available_technicians = db.query(Technician).filter(Technician.is_available == True).count()
    
    # Contar incidentes por estado
    total_incidents = db.query(Incident).count()
    pending_incidents = db.query(Incident).filter(Incident.status == IncidentStatus.PENDING).count()
    accepted_incidents = db.query(Incident).filter(Incident.status == IncidentStatus.ACCEPTED).count()
    in_progress_incidents = db.query(Incident).filter(Incident.status == IncidentStatus.IN_PROGRESS).count()
    completed_incidents = db.query(Incident).filter(Incident.status == IncidentStatus.COMPLETED).count()
    cancelled_incidents = db.query(Incident).filter(Incident.status == IncidentStatus.CANCELLED).count()
    
    # Contar incidentes por prioridad
    high_priority = db.query(Incident).filter(Incident.priority == IncidentPriority.HIGH).count()
    medium_priority = db.query(Incident).filter(Incident.priority == IncidentPriority.MEDIUM).count()
    low_priority = db.query(Incident).filter(Incident.priority == IncidentPriority.LOW).count()
    
    # Estadísticas de pagos
    total_payments = db.query(Payment).count()
    paid_payments = db.query(Payment).filter(Payment.is_paid == True).count()
    pending_payments = db.query(Payment).filter(Payment.is_paid == False).count()
    
    # Calcular totales de dinero
    total_revenue = db.query(func.sum(Payment.amount)).scalar() or 0
    total_commissions = db.query(func.sum(Payment.commission_amount)).scalar() or 0
    total_workshop_earnings = db.query(func.sum(Payment.workshop_earnings)).scalar() or 0
    
    # Estadísticas de los últimos 30 días
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    recent_incidents = db.query(Incident).filter(Incident.created_at >= thirty_days_ago).count()
    recent_payments = db.query(Payment).filter(Payment.created_at >= thirty_days_ago).count()
    recent_users = db.query(User).filter(User.created_at >= thirty_days_ago).count()
    
    return {
        "users": {
            "total": total_users,
            "clients": clients,
            "workshops": workshops,
            "technicians": technicians,
            "admins": admins,
            "recent_30_days": recent_users
        },
        "workshops": {
            "total": total_workshops,
            "active": active_workshops,
            "inactive": total_workshops - active_workshops
        },
        "technicians": {
            "total": total_technicians,
            "available": available_technicians,
            "busy": total_technicians - available_technicians
        },
        "incidents": {
            "total": total_incidents,
            "by_status": {
                "pending": pending_incidents,
                "accepted": accepted_incidents,
                "in_progress": in_progress_incidents,
                "completed": completed_incidents,
                "cancelled": cancelled_incidents
            },
            "by_priority": {
                "high": high_priority,
                "medium": medium_priority,
                "low": low_priority
            },
            "recent_30_days": recent_incidents
        },
        "payments": {
            "total": total_payments,
            "paid": paid_payments,
            "pending": pending_payments,
            "total_revenue": float(total_revenue),
            "total_commissions": float(total_commissions),
            "total_workshop_earnings": float(total_workshop_earnings),
            "recent_30_days": recent_payments
        }
    }


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
