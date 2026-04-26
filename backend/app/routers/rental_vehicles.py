from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database import get_db
from app.models import User, RentalVehicle, UserRole
from app.schemas import RentalVehicleCreate, RentalVehicleResponse, RentalVehicleUpdate
from app.auth import get_current_user

router = APIRouter(prefix="/rental-vehicles", tags=["rental-vehicles"])


def verify_admin(current_user: User):
    """
    Verifica que el usuario sea administrador.
    """
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso"
        )


# ==================== ADMIN ENDPOINTS (CRUD) ====================

@router.post("", response_model=RentalVehicleResponse)
async def create_rental_vehicle(
    vehicle_data: RentalVehicleCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Crear un nuevo vehículo de alquiler.
    Solo administradores.
    """
    verify_admin(current_user)
    
    new_vehicle = RentalVehicle(**vehicle_data.dict())
    db.add(new_vehicle)
    db.commit()
    db.refresh(new_vehicle)
    
    return new_vehicle


@router.get("", response_model=List[RentalVehicleResponse])
async def get_rental_vehicles(
    skip: int = 0,
    limit: int = 100,
    is_active: Optional[bool] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener lista de vehículos de alquiler.
    Solo administradores pueden ver todos.
    Clientes solo ven vehículos activos.
    """
    query = db.query(RentalVehicle)
    
    # Si no es admin, solo mostrar vehículos activos
    if current_user.role != UserRole.ADMIN:
        query = query.filter(RentalVehicle.is_active == True)
    else:
        # Admin puede filtrar por estado si lo especifica
        if is_active is not None:
            query = query.filter(RentalVehicle.is_active == is_active)
    
    vehicles = query.offset(skip).limit(limit).all()
    return vehicles


@router.get("/{vehicle_id}", response_model=RentalVehicleResponse)
async def get_rental_vehicle(
    vehicle_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener detalles de un vehículo de alquiler específico.
    """
    vehicle = db.query(RentalVehicle).filter(RentalVehicle.id == vehicle_id).first()
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo de alquiler no encontrado"
        )
    
    # Si no es admin, solo puede ver vehículos activos
    if current_user.role != UserRole.ADMIN and not vehicle.is_active:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo de alquiler no encontrado"
        )
    
    return vehicle


@router.patch("/{vehicle_id}", response_model=RentalVehicleResponse)
async def update_rental_vehicle(
    vehicle_id: int,
    vehicle_update: RentalVehicleUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Actualizar un vehículo de alquiler.
    Solo administradores.
    """
    verify_admin(current_user)
    
    vehicle = db.query(RentalVehicle).filter(RentalVehicle.id == vehicle_id).first()
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo de alquiler no encontrado"
        )
    
    # Actualizar solo los campos proporcionados
    update_data = vehicle_update.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(vehicle, field, value)
    
    db.commit()
    db.refresh(vehicle)
    
    return vehicle


@router.delete("/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_rental_vehicle(
    vehicle_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Eliminar un vehículo de alquiler.
    Solo administradores.
    """
    verify_admin(current_user)
    
    vehicle = db.query(RentalVehicle).filter(RentalVehicle.id == vehicle_id).first()
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehículo de alquiler no encontrado"
        )
    
    db.delete(vehicle)
    db.commit()
    
    return None
