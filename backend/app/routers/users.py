from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.database import get_db
from app import models, schemas
from app.auth import get_current_active_user
from app.auth import get_password_hash

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("/profile", response_model=schemas.UserResponse)
def get_profile(
    current_user: models.User = Depends(get_current_active_user)
):
    return current_user


@router.get("/me", response_model=schemas.UserResponse)
def get_current_user_info(
    current_user: models.User = Depends(get_current_active_user)
):
    return current_user


@router.patch("/me", response_model=schemas.UserResponse)
def update_my_profile(
    profile_data: schemas.UserSelfUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user)
):
    data = profile_data.dict(exclude_unset=True)

    if "full_name" in data:
        current_user.full_name = data["full_name"]

    if "phone" in data:
        current_user.phone = data["phone"]

    if "password" in data and data["password"]:
        current_user.hashed_password = get_password_hash(data["password"])

    db.commit()
    db.refresh(current_user)
    return current_user


@router.delete("/me")
def delete_my_account(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user)
):
    # Prevent deleting the only admin account via self-delete.
    if current_user.role == models.UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Los administradores no pueden eliminar su cuenta desde este endpoint"
        )

    if current_user.role == models.UserRole.WORKSHOP:
        workshops = db.query(models.Workshop).filter(models.Workshop.owner_id == current_user.id).all()
        workshop_ids = [w.id for w in workshops]

        if workshop_ids:
            db.query(models.Incident).filter(models.Incident.workshop_id.in_(workshop_ids)).update(
                {
                    models.Incident.workshop_id: None,
                    models.Incident.technician_id: None,
                    models.Incident.status: models.IncidentStatus.PENDING,
                    models.Incident.accepted_at: None,
                    models.Incident.started_at: None,
                    models.Incident.estimated_arrival_time: None
                },
                synchronize_session=False
            )

    db.delete(current_user)
    db.commit()

    return {"message": "Cuenta eliminada exitosamente"}
