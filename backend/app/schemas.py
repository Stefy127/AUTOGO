from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime
from enum import Enum


# Enums
class UserRole(str, Enum):
    CLIENT = "client"
    WORKSHOP = "workshop"
    TECHNICIAN = "technician"
    ADMIN = "admin"


class IncidentStatus(str, Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class IncidentPriority(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class PaymentMethod(str, Enum):
    CASH = "cash"
    TRANSFER = "transfer"


# User Schemas
class UserBase(BaseModel):
    email: EmailStr
    full_name: str
    phone: Optional[str] = None
    role: UserRole = UserRole.CLIENT


class UserCreate(UserBase):
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(UserBase):
    id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# Vehicle Schemas
class VehicleBase(BaseModel):
    brand: str
    model: str
    year: int = Field(..., ge=1900, le=2100)
    plate: str
    color: Optional[str] = None


class VehicleCreate(VehicleBase):
    pass


class VehicleResponse(VehicleBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# Incident Schemas
class IncidentBase(BaseModel):
    description: str
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    location_text: Optional[str] = None
    image_url: Optional[str] = None
    audio_url: Optional[str] = None


class IncidentCreate(IncidentBase):
    vehicle_id: int


class IncidentUpdate(BaseModel):
    status: Optional[IncidentStatus] = None
    description: Optional[str] = None
    priority: Optional[IncidentPriority] = None
    workshop_id: Optional[int] = None
    technician_id: Optional[int] = None


class IncidentResponse(IncidentBase):
    id: int
    user_id: int
    vehicle_id: int
    status: IncidentStatus
    priority: IncidentPriority
    workshop_id: Optional[int] = None
    technician_id: Optional[int] = None
    classification: Optional[str] = None
    ai_summary: Optional[str] = None
    estimated_arrival_time: Optional[int] = None
    accepted_at: Optional[datetime] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime
    user: Optional[UserResponse] = None
    vehicle: Optional[VehicleResponse] = None
    workshop: Optional['WorkshopResponse'] = None
    technician: Optional['TechnicianResponse'] = None
    payment: Optional['PaymentResponse'] = None

    class Config:
        from_attributes = True


class IncidentAccept(BaseModel):
    """Schema para aceptar incidente con técnico y tarifa"""
    technician_id: int
    estimated_amount: float = Field(..., gt=0, description="Monto estimado del servicio")


# Token Schemas
class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    email: Optional[str] = None


# Workshop Schemas
class WorkshopBase(BaseModel):
    name: str
    address: str
    latitude: float
    longitude: float
    commission_percentage: float = 10.0
    is_active: bool = True


class WorkshopCreate(WorkshopBase):
    pass


class WorkshopUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    commission_percentage: Optional[float] = None
    is_active: Optional[bool] = None


class WorkshopResponse(WorkshopBase):
    id: int
    owner_id: int
    created_at: datetime
    updated_at: datetime
    owner: Optional[UserResponse] = None

    class Config:
        from_attributes = True


# Technician Schemas
class TechnicianBase(BaseModel):
    name: str
    phone: Optional[str] = None
    is_available: bool = True
    current_latitude: Optional[float] = None
    current_longitude: Optional[float] = None


class TechnicianCreateSimple(BaseModel):
    """Schema para crear técnico sin especificar workshop_id (se extrae del usuario)"""
    name: str
    phone: Optional[str] = None


class TechnicianCreate(TechnicianBase):
    workshop_id: int
    user_id: Optional[int] = None


class TechnicianUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    is_available: Optional[bool] = None
    current_latitude: Optional[float] = None
    current_longitude: Optional[float] = None


class TechnicianResponse(TechnicianBase):
    id: int
    workshop_id: int
    user_id: Optional[int] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# Payment Schemas
class PaymentBase(BaseModel):
    amount: float = Field(..., gt=0)
    payment_method: PaymentMethod
    reference_number: Optional[str] = None
    notes: Optional[str] = None


class PaymentCreate(PaymentBase):
    incident_id: int


class PaymentUpdate(BaseModel):
    is_paid: Optional[bool] = None
    paid_at: Optional[datetime] = None
    reference_number: Optional[str] = None
    notes: Optional[str] = None


class PaymentResponse(PaymentBase):
    id: int
    incident_id: int
    commission_percentage: float
    commission_amount: float
    workshop_earnings: float
    is_paid: bool
    paid_at: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# IncidentHistory Schemas
class IncidentHistoryCreate(BaseModel):
    incident_id: int
    status: IncidentStatus
    notes: Optional[str] = None


class IncidentHistoryResponse(BaseModel):
    id: int
    incident_id: int
    status: IncidentStatus
    changed_by_user_id: int
    notes: Optional[str] = None
    timestamp: datetime

    class Config:
        from_attributes = True


# Resolve forward refs declared in IncidentResponse
IncidentResponse.model_rebuild()

