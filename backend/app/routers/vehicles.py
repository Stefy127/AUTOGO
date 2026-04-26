from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app import models, schemas
from app.auth import get_current_active_user

router = APIRouter(prefix="/vehicles", tags=["Vehicles"])


@router.post("", response_model=schemas.VehicleResponse, status_code=status.HTTP_201_CREATED)
def create_vehicle(
    vehicle: schemas.VehicleCreate,
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    # Check if plate already exists
    existing_vehicle = db.query(models.Vehicle).filter(
        models.Vehicle.plate == vehicle.plate
    ).first()
    
    if existing_vehicle:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Vehicle with this plate already exists"
        )
    
    db_vehicle = models.Vehicle(
        **vehicle.dict(),
        user_id=current_user.id
    )
    db.add(db_vehicle)
    db.commit()
    db.refresh(db_vehicle)
    return db_vehicle


@router.get("", response_model=List[schemas.VehicleResponse])
def get_user_vehicles(
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    vehicles = db.query(models.Vehicle).filter(
        models.Vehicle.user_id == current_user.id
    ).all()
    return vehicles


@router.get("/{vehicle_id}", response_model=schemas.VehicleResponse)
def get_vehicle(
    vehicle_id: int,
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    vehicle = db.query(models.Vehicle).filter(
        models.Vehicle.id == vehicle_id,
        models.Vehicle.user_id == current_user.id
    ).first()
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found"
        )
    
    return vehicle


@router.put("/{vehicle_id}", response_model=schemas.VehicleResponse)
def update_vehicle(
    vehicle_id: int,
    vehicle_data: schemas.VehicleUpdate,
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    vehicle = db.query(models.Vehicle).filter(
        models.Vehicle.id == vehicle_id,
        models.Vehicle.user_id == current_user.id
    ).first()

    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found"
        )

    data = vehicle_data.dict(exclude_unset=True)

    if "plate" in data:
        normalized_plate = data["plate"].upper()
        existing_plate = db.query(models.Vehicle).filter(
            models.Vehicle.plate == normalized_plate,
            models.Vehicle.id != vehicle.id
        ).first()
        if existing_plate:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Vehicle with this plate already exists"
            )
        data["plate"] = normalized_plate

    for field, value in data.items():
        setattr(vehicle, field, value)

    db.commit()
    db.refresh(vehicle)
    return vehicle


@router.delete("/{vehicle_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_vehicle(
    vehicle_id: int,
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    vehicle = db.query(models.Vehicle).filter(
        models.Vehicle.id == vehicle_id,
        models.Vehicle.user_id == current_user.id
    ).first()
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found"
        )
    
    db.delete(vehicle)
    db.commit()
    return None
