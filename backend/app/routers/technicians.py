from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timedelta
import secrets

from app.database import get_db
from app.models import User, Workshop, Technician, Incident, UserRole, IncidentStatus
from app.schemas import TechnicianCreateSimple, TechnicianUpdate, TechnicianResponse
from app.auth import get_current_user

router = APIRouter(prefix="/technicians", tags=["technicians"])


def _generate_access_code() -> str:
    # Short code optimized for manual mechanic entry.
    return secrets.token_hex(3).upper()


def _get_my_workshop(db: Session, current_user: User) -> Workshop:
    if current_user.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo usuarios con rol WORKSHOP pueden gestionar técnicos"
        )

    workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un taller para este usuario"
        )
    return workshop


@router.post("", response_model=TechnicianResponse, status_code=status.HTTP_201_CREATED)
def create_technician(
    technician_data: TechnicianCreateSimple,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    workshop = _get_my_workshop(db, current_user)

    technician = Technician(
        workshop_id=workshop.id,
        name=technician_data.name,
        phone=technician_data.phone,
        access_code=_generate_access_code(),
        access_code_expires_at=datetime.utcnow() + timedelta(hours=24),
        is_active=True,
        is_available=True
    )

    db.add(technician)
    db.commit()
    db.refresh(technician)
    return technician


@router.get("", response_model=List[TechnicianResponse])
def get_technicians(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    workshop = _get_my_workshop(db, current_user)
    return db.query(Technician).filter(Technician.workshop_id == workshop.id).all()


@router.put("/{technician_id}", response_model=TechnicianResponse)
def update_technician(
    technician_id: int,
    technician_data: TechnicianUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    workshop = _get_my_workshop(db, current_user)

    technician = db.query(Technician).filter(
        Technician.id == technician_id,
        Technician.workshop_id == workshop.id
    ).first()

    if not technician:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Técnico no encontrado"
        )

    data = technician_data.dict(exclude_unset=True)
    for field, value in data.items():
        setattr(technician, field, value)

    db.commit()
    db.refresh(technician)
    return technician


@router.post("/{technician_id}/access-code/regenerate", response_model=TechnicianResponse)
def regenerate_access_code(
    technician_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    workshop = _get_my_workshop(db, current_user)

    technician = db.query(Technician).filter(
        Technician.id == technician_id,
        Technician.workshop_id == workshop.id
    ).first()

    if not technician:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Técnico no encontrado"
        )

    technician.access_code = _generate_access_code()
    technician.access_code_expires_at = datetime.utcnow() + timedelta(hours=24)

    db.commit()
    db.refresh(technician)
    return technician


@router.delete("/{technician_id}")
def delete_technician(
    technician_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    workshop = _get_my_workshop(db, current_user)

    technician = db.query(Technician).filter(
        Technician.id == technician_id,
        Technician.workshop_id == workshop.id
    ).first()

    if not technician:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Técnico no encontrado"
        )

    active_incident = db.query(Incident).filter(
        Incident.technician_id == technician.id,
        Incident.status.in_([
            IncidentStatus.ACCEPTED,
            IncidentStatus.IN_PROGRESS
        ])
    ).first()

    if active_incident:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No puedes eliminar un técnico con incidentes activos"
        )

    db.delete(technician)
    db.commit()

    return {"message": "Técnico eliminado exitosamente"}
