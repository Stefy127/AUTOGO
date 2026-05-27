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
    WAITING_OFFERS = "waiting_offers"
    ASSIGNED = "assigned"
    ACCEPTED = "accepted"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class OfferStatus(str, Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"


class IncidentPriority(str, Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class PaymentMethod(str, Enum):
    CASH = "cash"
    TRANSFER = "transfer"
    QR = "qr"


class VehicleType(str, Enum):
    AUTOMOVIL = "automovil"
    CAMIONETA = "camioneta"


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


class UserSelfUpdate(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None
    password: Optional[str] = None


class UserProfileUpdate(BaseModel):
    email: EmailStr
    full_name: str
    phone: Optional[str] = None


class AdminUserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    phone: Optional[str] = None
    role: Optional[UserRole] = None


# Vehicle Schemas
class VehicleBase(BaseModel):
    brand: str
    model: str
    year: int = Field(..., ge=1900, le=2100)
    plate: str
    color: Optional[str] = None


class VehicleCreate(VehicleBase):
    pass


class VehicleUpdate(BaseModel):
    brand: Optional[str] = None
    model: Optional[str] = None
    year: Optional[int] = Field(default=None, ge=1900, le=2100)
    plate: Optional[str] = None
    color: Optional[str] = None


class VehicleResponse(VehicleBase):
    id: int
    user_id: int
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


# Rental Vehicle Schemas
class RentalVehicleBase(BaseModel):
    company_name: str
    vehicle_type: VehicleType
    vehicle_name: str
    characteristics: str
    photo_url: Optional[str] = None
    whatsapp_number: str


class RentalVehicleCreate(RentalVehicleBase):
    pass


class RentalVehicleUpdate(BaseModel):
    company_name: Optional[str] = None
    vehicle_type: Optional[VehicleType] = None
    vehicle_name: Optional[str] = None
    characteristics: Optional[str] = None
    photo_url: Optional[str] = None
    whatsapp_number: Optional[str] = None
    is_active: Optional[bool] = None


class RentalVehicleResponse(RentalVehicleBase):
    id: int
    is_active: bool
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
    payment_method: Optional[PaymentMethod] = None
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
    offers: list['OfferResponse'] = Field(default_factory=list)

    class Config:
        from_attributes = True


class IncidentAccept(BaseModel):
    """Schema para aceptar incidente con técnico y tarifa"""
    technician_id: int
    estimated_amount: float = Field(..., gt=0, description="Monto estimado del servicio")


class OfferCreate(BaseModel):
    incident_id: int
    amount: float = Field(..., gt=0)
    technician_id: Optional[int] = None
    estimated_arrival_time: Optional[int] = Field(default=None, ge=1)
    notes: Optional[str] = None


class OfferAccept(BaseModel):
    technician_id: Optional[int] = None


class OfferResponse(BaseModel):
    id: int
    incident_id: int
    workshop_id: int
    technician_id: Optional[int] = None
    amount: float
    estimated_arrival_time: Optional[int] = None
    notes: Optional[str] = None
    status: OfferStatus
    created_at: datetime
    updated_at: datetime
    workshop: Optional['WorkshopResponse'] = None
    technician: Optional['TechnicianResponse'] = None

    class Config:
        from_attributes = True


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


class WorkshopPaymentQRUpsert(BaseModel):
    qr_image_url: str


class WorkshopPaymentQRResponse(BaseModel):
    workshop_id: int
    qr_image_url: str
    updated_at: Optional[datetime] = None

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
    access_code: Optional[str] = None
    access_code_expires_at: Optional[datetime] = None
    is_active: bool = True
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


class PaymentQRConfirm(BaseModel):
    reference_number: Optional[str] = None


class TechnicianAccessRequest(BaseModel):
    code: str
    name: str


class TechnicianAccessResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    technician_id: int
    technician_name: str
    workshop_id: int
    workshop_name: str
    expires_at: Optional[datetime] = None


class TechnicianIncidentStatusUpdate(BaseModel):
    status: IncidentStatus


class TechnicianPaymentConfirm(BaseModel):
    incident_id: int
    payment_method: PaymentMethod


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


class AuditLogCreate(BaseModel):
    event_type: str
    action: str
    section: Optional[str] = None
    endpoint: Optional[str] = None
    http_method: Optional[str] = None
    details: Optional[str] = None


class AuditLogResponse(BaseModel):
    id: int
    user_id: Optional[int] = None
    user_email: Optional[str] = None
    user_full_name: Optional[str] = None
    user_role: Optional[UserRole] = None
    event_type: str
    action: str
    section: Optional[str] = None
    endpoint: Optional[str] = None
    http_method: Optional[str] = None
    details: Optional[str] = None
    created_at: datetime


class NotificationResponse(BaseModel):
    id: int
    user_id: int
    incident_id: Optional[int] = None
    title: str
    message: str
    notification_type: str
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


# Resolve forward refs declared in IncidentResponse
IncidentResponse.model_rebuild()

