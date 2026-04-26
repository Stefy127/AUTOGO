from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
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


@router.put("/profile", response_model=schemas.UserResponse)
def update_profile(
    profile_data: schemas.UserProfileUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user)
):
    existing_user = db.query(models.User).filter(
        models.User.email == profile_data.email,
        models.User.id != current_user.id
    ).first()

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El email ya está registrado por otro usuario"
        )

    current_user.email = profile_data.email
    current_user.full_name = profile_data.full_name
    current_user.phone = profile_data.phone

    db.commit()
    db.refresh(current_user)
    return current_user


@router.delete("/profile")
def delete_profile(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user)
):
    return _delete_user_account(db, current_user)


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
    return _delete_user_account(db, current_user)


def _delete_user_account(db: Session, current_user: models.User):
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
