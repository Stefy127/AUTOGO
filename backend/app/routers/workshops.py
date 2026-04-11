from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

from app.database import get_db
from app.models import User, Workshop, Technician, Incident, IncidentStatus, IncidentHistory, UserRole, Payment, PaymentMethod
from app.schemas import (
    WorkshopCreate, WorkshopResponse, WorkshopUpdate,
    TechnicianCreate, TechnicianCreateSimple, TechnicianResponse,
    IncidentResponse, IncidentAccept
)
from app.auth import get_current_user
from app.services.assignment_service import AssignmentService
from app.services.mapbox_service import MapboxService

router = APIRouter(prefix="/workshops", tags=["workshops"])

# Initialize services
mapbox_service = MapboxService()


# ==================== WORKSHOP MANAGEMENT ====================

@router.post("", response_model=WorkshopResponse, status_code=status.HTTP_201_CREATED)
async def create_workshop(
    workshop_data: WorkshopCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Registrar un nuevo taller.
    Solo usuarios con rol WORKSHOP pueden registrar un taller.
    """
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden registrar talleres"
        )
    
    # Verificar que el usuario no tenga ya un taller
    existing_workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
    if existing_workshop:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Este usuario ya tiene un taller registrado"
        )
    
    # Crear el taller
    new_workshop = Workshop(
        owner_id=current_user.id,
        name=workshop_data.name,
        address=workshop_data.address,
        latitude=workshop_data.latitude,
        longitude=workshop_data.longitude,
        commission_percentage=workshop_data.commission_percentage,
        is_active=workshop_data.is_active
    )
    
    db.add(new_workshop)
    db.commit()
    db.refresh(new_workshop)
    
    return new_workshop


@router.get("/me", response_model=WorkshopResponse)
async def get_my_workshop(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener información del taller propio.
    """
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden acceder a esta información"
        )
    
    workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un taller para este usuario"
        )
    
    return workshop


@router.patch("/me", response_model=WorkshopResponse)
async def update_my_workshop(
    workshop_data: WorkshopUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Actualizar información del taller propio.
    """
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden actualizar talleres"
        )
    
    workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un taller para este usuario"
        )
    
    # Actualizar solo los campos proporcionados
    update_data = workshop_data.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(workshop, field, value)
    
    db.commit()
    db.refresh(workshop)
    
    return workshop


# ==================== TECHNICIAN MANAGEMENT ====================

@router.post("/me/technicians", response_model=TechnicianResponse, status_code=status.HTTP_201_CREATED)
async def add_technician_to_my_workshop(
    technician_data: TechnicianCreateSimple,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Agregar un técnico al taller propio (extrae workshop_id del usuario actual).
    """
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden agregar técnicos"
        )
    
    # Buscar el taller del usuario actual
    workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un taller para este usuario. Crea tu perfil de taller primero."
        )
    
    # Crear el técnico
    new_technician = Technician(
        workshop_id=workshop.id,
        user_id=None,
        name=technician_data.name,
        phone=technician_data.phone,
        is_available=True,
        current_latitude=None,
        current_longitude=None
    )
    
    db.add(new_technician)
    db.commit()
    db.refresh(new_technician)
    
    return new_technician


@router.post("/{workshop_id}/technicians", response_model=TechnicianResponse, status_code=status.HTTP_201_CREATED)
async def add_technician(
    workshop_id: int,
    technician_data: TechnicianCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Agregar un técnico al taller.
    """
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden agregar técnicos"
        )
    
    # Verificar que el taller pertenece al usuario actual
    workshop = db.query(Workshop).filter(Workshop.id == workshop_id, Workshop.owner_id == current_user.id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Taller no encontrado o no tienes permisos"
        )
    
    # Crear el técnico
    new_technician = Technician(
        workshop_id=workshop_id,
        user_id=technician_data.user_id,
        name=technician_data.name,
        phone=technician_data.phone,
        is_available=technician_data.is_available,
        current_latitude=technician_data.current_latitude,
        current_longitude=technician_data.current_longitude
    )
    
    db.add(new_technician)
    db.commit()
    db.refresh(new_technician)
    
    return new_technician


@router.get("/me/technicians", response_model=List[TechnicianResponse])
async def get_my_technicians(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener todos los técnicos del taller propio.
    """
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden acceder a esta información"
        )
    
    workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un taller para este usuario"
        )
    
    technicians = db.query(Technician).filter(Technician.workshop_id == workshop.id).all()
    
    return technicians


# ==================== INCIDENT MANAGEMENT ====================

@router.get("/incidents/available", response_model=List[IncidentResponse])
async def get_available_incidents(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener incidentes disponibles para asignar.
    Solo muestra incidentes PENDING que estén dentro del rango de cobertura.
    """
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden acceder a esta información"
        )
    
    workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un taller para este usuario"
        )
    
    # Obtener incidentes pendientes sin asignar
    incidents = db.query(Incident).filter(
        Incident.status == IncidentStatus.PENDING,
        Incident.workshop_id.is_(None)
    ).all()
    
    # TODO: Filtrar por distancia usando MapboxService
    # Por ahora retornamos todos los incidentes pendientes
    
    return incidents


@router.post("/incidents/{incident_id}/accept", response_model=IncidentResponse)
async def accept_incident(
    incident_id: int,
    accept_data: IncidentAccept,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Aceptar un incidente, asignar un técnico y crear el pago con la tarifa estimada.
    """
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden aceptar incidentes"
        )
    
    workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un taller para este usuario"
        )
    
    # Verificar que el incidente existe y está pendiente
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incidente no encontrado"
        )
    
    if incident.status != IncidentStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"El incidente ya fue {incident.status}"
        )
    
    # Verificar que el técnico pertenece al taller
    technician = db.query(Technician).filter(
        Technician.id == accept_data.technician_id,
        Technician.workshop_id == workshop.id
    ).first()
    
    if not technician:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Técnico no encontrado o no pertenece a tu taller"
        )
    
    if not technician.is_available:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El técnico no está disponible"
        )
    
    # Asignar el incidente
    incident.workshop_id = workshop.id
    incident.technician_id = accept_data.technician_id
    incident.status = IncidentStatus.ACCEPTED
    incident.accepted_at = datetime.utcnow()
    
    # Calcular tiempo estimado de llegada basado en distancia (minutos)
    if workshop.latitude and workshop.longitude and incident.latitude and incident.longitude:
        distance_info = await mapbox_service.get_distance_and_duration(
            workshop.latitude,
            workshop.longitude,
            incident.latitude,
            incident.longitude
        )
        
        if distance_info:
            # Add some preparation time (5 minutes) to the travel duration
            total_minutes = distance_info.get("duration_minutes", 0) + 5
            incident.estimated_arrival_time = total_minutes
    
    # Marcar técnico como no disponible
    technician.is_available = False
    
    # Crear pago automáticamente con la tarifa estimada
    commission_rate = (workshop.commission_percentage or 10.0) / 100.0
    commission_amount = accept_data.estimated_amount * commission_rate
    workshop_earnings = accept_data.estimated_amount - commission_amount
    
    payment = Payment(
        incident_id=incident_id,
        amount=accept_data.estimated_amount,
        payment_method=PaymentMethod.CASH,  # Default, puede ser actualizado después
        commission_percentage=commission_rate,
        commission_amount=commission_amount,
        workshop_earnings=workshop_earnings,
        is_paid=False
    )
    db.add(payment)
    
    # Registrar en el historial
    history_notes = f"Incidente aceptado por taller {workshop.name}, asignado a técnico {technician.name}. Tarifa estimada: ${accept_data.estimated_amount:.2f}"
    if incident.estimated_arrival_time:
        history_notes += f". Llegada estimada: {incident.estimated_arrival_time} minutos"
    
    history = IncidentHistory(
        incident_id=incident_id,
        status=IncidentStatus.ACCEPTED,
        changed_by_user_id=current_user.id,
        notes=history_notes
    )
    db.add(history)
    
    db.commit()
    db.refresh(incident)
    
    return incident


@router.post("/incidents/{incident_id}/reject")
async def reject_incident(
    incident_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Rechazar un incidente (no hace nada, solo para registro).
    """
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden rechazar incidentes"
        )
    
    workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un taller para este usuario"
        )
    
    # Verificar que el incidente existe
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incidente no encontrado"
        )
    
    # Registrar en el historial (opcional)
    history = IncidentHistory(
        incident_id=incident_id,
        status=incident.status,  # Mantiene el estado actual
        changed_by_user_id=current_user.id,
        notes=f"Incidente rechazado por taller {workshop.name}"
    )
    db.add(history)
    db.commit()
    
    return {"message": "Incidente rechazado", "incident_id": incident_id}


@router.get("/me/incidents", response_model=List[IncidentResponse])
async def get_my_incidents(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener todos los incidentes asignados al taller.
    """
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden acceder a esta información"
        )
    
    workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un taller para este usuario"
        )
    
    incidents = db.query(Incident).filter(Incident.workshop_id == workshop.id).all()
    
    return incidents


# ==================== STATS ====================

@router.get("/me/stats")
async def get_workshop_stats(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener estadísticas del taller.
    """
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden acceder a esta información"
        )
    
    workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un taller para este usuario"
        )
    
    # Contar incidentes por estado
    total_incidents = db.query(Incident).filter(Incident.workshop_id == workshop.id).count()
    accepted_incidents = db.query(Incident).filter(
        Incident.workshop_id == workshop.id,
        Incident.status == IncidentStatus.ACCEPTED
    ).count()
    in_progress_incidents = db.query(Incident).filter(
        Incident.workshop_id == workshop.id,
        Incident.status == IncidentStatus.IN_PROGRESS
    ).count()
    completed_incidents = db.query(Incident).filter(
        Incident.workshop_id == workshop.id,
        Incident.status == IncidentStatus.COMPLETED
    ).count()
    
    # Contar técnicos
    total_technicians = db.query(Technician).filter(Technician.workshop_id == workshop.id).count()
    available_technicians = db.query(Technician).filter(
        Technician.workshop_id == workshop.id,
        Technician.is_available == True
    ).count()
    
    return {
        "workshop_id": workshop.id,
        "workshop_name": workshop.name,
        "total_incidents": total_incidents,
        "accepted_incidents": accepted_incidents,
        "in_progress_incidents": in_progress_incidents,
        "completed_incidents": completed_incidents,
        "total_technicians": total_technicians,
        "available_technicians": available_technicians
    }
