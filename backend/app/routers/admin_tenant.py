from datetime import datetime, timedelta
from typing import List, Optional
import secrets

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.auth import get_current_user, get_password_hash
from app.database import get_db
from app.models import User, UserRole, Workshop, Technician
from app.schemas import (
    TenantTechnicianCreate,
    TenantTechnicianStatusUpdate,
    TenantTechnicianUpdate,
    TenantWorkshopCreate,
    TenantWorkshopOwnerOption,
    TenantWorkshopResponse,
    TenantWorkshopStatusUpdate,
    TenantWorkshopUpdate,
    TenantWorkshopWithOwnerCreate,
    TenantWorkshopUserRow,
)

router = APIRouter(prefix="/admin/tenant", tags=["admin-tenant"])


def verify_admin(current_user: User) -> None:
    if current_user.role != UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo administradores pueden acceder a este recurso",
        )


def _generate_access_code() -> str:
    return secrets.token_hex(3).upper()


def _get_workshop_or_404(db: Session, workshop_id: int) -> Workshop:
    workshop = db.query(Workshop).filter(Workshop.id == workshop_id).first()
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Taller no encontrado",
        )
    return workshop


def _get_technician_or_404(db: Session, technician_id: int) -> Technician:
    technician = db.query(Technician).filter(Technician.id == technician_id).first()
    if not technician:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Técnico no encontrado",
        )
    return technician


def _build_workshop_response(db: Session, workshop: Workshop) -> TenantWorkshopResponse:
    owner = db.query(User).filter(User.id == workshop.owner_id).first()
    technician_count = db.query(Technician).filter(Technician.workshop_id == workshop.id).count()
    active_technician_count = db.query(Technician).filter(
        Technician.workshop_id == workshop.id,
        Technician.is_active == True,
    ).count()

    return TenantWorkshopResponse(
        id=workshop.id,
        name=workshop.name,
        address=workshop.address,
        latitude=workshop.latitude,
        longitude=workshop.longitude,
        commission_percentage=workshop.commission_percentage,
        is_active=workshop.is_active,
        owner_id=workshop.owner_id,
        owner_name=owner.full_name if owner else None,
        owner_email=owner.email if owner else None,
        owner_phone=owner.phone if owner else None,
        technician_count=technician_count,
        active_technician_count=active_technician_count,
        created_at=workshop.created_at,
        updated_at=workshop.updated_at,
    )


def _build_technician_row(db: Session, technician: Technician) -> TenantWorkshopUserRow:
    user = db.query(User).filter(User.id == technician.user_id).first() if technician.user_id else None

    return TenantWorkshopUserRow(
        row_type="technician",
        relation="Técnico del taller",
        user_id=user.id if user else None,
        technician_id=technician.id,
        workshop_id=technician.workshop_id,
        full_name=user.full_name if user else technician.name,
        email=user.email if user else None,
        phone=user.phone if user else technician.phone,
        role=UserRole.TECHNICIAN,
        is_active=technician.is_active,
        is_available=technician.is_available,
        access_code=technician.access_code,
    )


@router.get("/workshops", response_model=List[TenantWorkshopResponse])
def get_tenant_workshops(
    search: Optional[str] = None,
    is_active: Optional[bool] = None,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_admin(current_user)

    query = db.query(Workshop).join(User, Workshop.owner_id == User.id)

    if is_active is not None:
        query = query.filter(Workshop.is_active == is_active)

    if search:
        term = f"%{search.strip()}%"
        query = query.filter(
            or_(
                Workshop.name.ilike(term),
                Workshop.address.ilike(term),
                User.full_name.ilike(term),
                User.email.ilike(term),
            )
        )

    workshops = query.order_by(Workshop.id.desc()).offset(skip).limit(limit).all()
    return [_build_workshop_response(db, workshop) for workshop in workshops]


@router.get("/workshops/{workshop_id}", response_model=TenantWorkshopResponse)
def get_tenant_workshop(
    workshop_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_admin(current_user)
    workshop = _get_workshop_or_404(db, workshop_id)
    return _build_workshop_response(db, workshop)


@router.get("/workshop-owners", response_model=List[TenantWorkshopOwnerOption])
def get_tenant_workshop_owners(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_admin(current_user)

    users = db.query(User).filter(User.role == UserRole.WORKSHOP).order_by(User.full_name.asc()).all()
    response: List[TenantWorkshopOwnerOption] = []

    for user in users:
        workshop = db.query(Workshop).filter(Workshop.owner_id == user.id).first()
        response.append(
            TenantWorkshopOwnerOption(
                id=user.id,
                full_name=user.full_name,
                email=user.email,
                phone=user.phone,
                role=user.role,
                has_workshop=workshop is not None,
                workshop_id=workshop.id if workshop else None,
            )
        )

    return response


@router.post("/workshops", response_model=TenantWorkshopResponse, status_code=status.HTTP_201_CREATED)
def create_tenant_workshop(
    payload: TenantWorkshopCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_admin(current_user)

    owner = db.query(User).filter(User.id == payload.owner_id).first()
    if not owner:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Owner no encontrado")
    if owner.role != UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="El owner debe tener rol workshop",
        )

    existing = db.query(Workshop).filter(Workshop.owner_id == payload.owner_id).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Este usuario workshop ya tiene un taller asociado",
        )

    workshop = Workshop(
        owner_id=payload.owner_id,
        name=payload.name,
        address=payload.address,
        latitude=payload.latitude,
        longitude=payload.longitude,
        commission_percentage=payload.commission_percentage,
        is_active=payload.is_active,
    )

    db.add(workshop)
    db.commit()
    db.refresh(workshop)
    return _build_workshop_response(db, workshop)


@router.post("/workshops/with-owner", response_model=TenantWorkshopResponse, status_code=status.HTTP_201_CREATED)
def create_tenant_workshop_with_owner(
    payload: TenantWorkshopWithOwnerCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_admin(current_user)

    existing_user = db.query(User).filter(User.email == payload.owner.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El correo ya esta en uso",
        )

    try:
        owner = User(
            email=payload.owner.email,
            hashed_password=get_password_hash(payload.owner.password),
            full_name=payload.owner.full_name,
            phone=payload.owner.phone,
            role=UserRole.WORKSHOP,
        )
        db.add(owner)
        db.flush()

        workshop = Workshop(
            owner_id=owner.id,
            name=payload.workshop.name,
            address=payload.workshop.address,
            latitude=payload.workshop.latitude,
            longitude=payload.workshop.longitude,
            commission_percentage=payload.workshop.commission_percentage,
            is_active=payload.workshop.is_active,
        )
        db.add(workshop)
        db.commit()
        db.refresh(workshop)
    except Exception:
        db.rollback()
        raise

    return _build_workshop_response(db, workshop)


@router.put("/workshops/{workshop_id}", response_model=TenantWorkshopResponse)
def update_tenant_workshop(
    workshop_id: int,
    payload: TenantWorkshopUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_admin(current_user)
    workshop = _get_workshop_or_404(db, workshop_id)

    data = payload.dict(exclude_unset=True)
    for field in ["name", "address", "latitude", "longitude", "commission_percentage", "is_active"]:
        if field in data:
            setattr(workshop, field, data[field])

    db.commit()
    db.refresh(workshop)
    return _build_workshop_response(db, workshop)


@router.patch("/workshops/{workshop_id}/status", response_model=TenantWorkshopResponse)
def update_tenant_workshop_status(
    workshop_id: int,
    payload: TenantWorkshopStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_admin(current_user)
    workshop = _get_workshop_or_404(db, workshop_id)

    workshop.is_active = payload.is_active
    db.commit()
    db.refresh(workshop)
    return _build_workshop_response(db, workshop)


@router.get("/workshops/{workshop_id}/users", response_model=List[TenantWorkshopUserRow])
def get_tenant_workshop_users(
    workshop_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_admin(current_user)
    workshop = _get_workshop_or_404(db, workshop_id)

    rows: List[TenantWorkshopUserRow] = []
    owner = db.query(User).filter(User.id == workshop.owner_id).first()
    if owner:
        rows.append(
            TenantWorkshopUserRow(
                row_type="owner",
                relation="Dueño del taller",
                user_id=owner.id,
                technician_id=None,
                workshop_id=workshop.id,
                full_name=owner.full_name,
                email=owner.email,
                phone=owner.phone,
                role=owner.role,
                is_active=workshop.is_active,
                is_available=None,
                access_code=None,
            )
        )

    technicians = db.query(Technician).filter(Technician.workshop_id == workshop.id).order_by(Technician.id.asc()).all()
    rows.extend(_build_technician_row(db, technician) for technician in technicians)

    return rows


@router.post(
    "/workshops/{workshop_id}/technicians",
    response_model=TenantWorkshopUserRow,
    status_code=status.HTTP_201_CREATED,
)
def create_tenant_technician(
    workshop_id: int,
    payload: TenantTechnicianCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_admin(current_user)
    workshop = _get_workshop_or_404(db, workshop_id)

    existing = db.query(User).filter(User.email == payload.email).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El correo ya está en uso",
        )

    user = User(
        email=payload.email,
        hashed_password=get_password_hash(payload.password),
        full_name=payload.full_name,
        phone=payload.phone,
        role=UserRole.TECHNICIAN,
    )
    db.add(user)
    db.flush()

    technician = Technician(
        workshop_id=workshop.id,
        user_id=user.id,
        name=payload.full_name,
        phone=payload.phone,
        access_code=_generate_access_code(),
        access_code_expires_at=datetime.utcnow() + timedelta(hours=24),
        is_active=payload.is_active,
        is_available=payload.is_available if payload.is_active else False,
    )
    db.add(technician)
    db.commit()
    db.refresh(technician)

    return _build_technician_row(db, technician)


@router.put("/technicians/{technician_id}", response_model=TenantWorkshopUserRow)
def update_tenant_technician(
    technician_id: int,
    payload: TenantTechnicianUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_admin(current_user)
    technician = _get_technician_or_404(db, technician_id)

    data = payload.dict(exclude_unset=True)

    if "full_name" in data:
        technician.name = data["full_name"]
    if "phone" in data:
        technician.phone = data["phone"]
    if "is_active" in data:
        technician.is_active = data["is_active"]
    if "is_available" in data:
        technician.is_available = data["is_available"]

    if technician.is_active is False:
        technician.is_available = False

    if technician.user_id:
        user = db.query(User).filter(User.id == technician.user_id).first()
        if user:
            if "full_name" in data:
                user.full_name = data["full_name"]
            if "phone" in data:
                user.phone = data["phone"]

    db.commit()
    db.refresh(technician)
    return _build_technician_row(db, technician)


@router.patch("/technicians/{technician_id}/status", response_model=TenantWorkshopUserRow)
def update_tenant_technician_status(
    technician_id: int,
    payload: TenantTechnicianStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    verify_admin(current_user)
    technician = _get_technician_or_404(db, technician_id)

    technician.is_active = payload.is_active
    if not payload.is_active:
        technician.is_available = False

    db.commit()
    db.refresh(technician)
    return _build_technician_row(db, technician)
