from pydantic import BaseModel, EmailStr, Field
from typing import Optional, Literal, Any
from datetime import datetime, date
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
    ON_ROUTE = "on_route"
    IN_SERVICE = "in_service"
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


class AdminWorkshopUserCreate(BaseModel):
    full_name: str
    email: EmailStr
    password: str
    phone: Optional[str] = None
    role: UserRole


class AdminUserStatusUpdate(BaseModel):
    is_active: bool


class AdminTechnicianStatusUpdate(BaseModel):
    is_active: bool


class AdminTechnicianUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    is_active: Optional[bool] = None
    is_available: Optional[bool] = None


class AdminWorkshopUserResponse(BaseModel):
    user_id: Optional[int] = None
    full_name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None
    role: Optional[UserRole] = None
    relation: str
    workshop_id: int
    technician_id: Optional[int] = None
    is_active: bool = True
    is_available: Optional[bool] = None
    access_code: Optional[str] = None


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
    location_selected: Optional[bool] = None
    image_url: Optional[str] = None
    audio_url: Optional[str] = None


class IncidentCreate(IncidentBase):
    vehicle_id: int


class OfflineIncidentSyncRequest(BaseModel):
    client_offline_id: str = Field(..., min_length=1)
    client_email: EmailStr
    client_phone: Optional[str] = None
    vehicle_brand: str = Field(..., min_length=1)
    vehicle_model: str = Field(..., min_length=1)
    vehicle_year: int = Field(..., ge=1900, le=2100)
    vehicle_plate: str = Field(..., min_length=1)
    incident_type: Optional[str] = None
    description: str = Field(..., min_length=1)
    address: str = Field(..., min_length=1)
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    created_offline_at: datetime


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
    remaining_distance_meters: Optional[int] = None
    route_polyline: Optional[str] = None
    last_eta_update_at: Optional[datetime] = None
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
    technician_id: Optional[int] = None
    estimated_arrival_time: Optional[int] = Field(default=None, ge=1)
    diagnosis_cost: Optional[float] = Field(default=None, ge=0)
    labor_cost: Optional[float] = Field(default=None, ge=0)
    parts_cost: Optional[float] = Field(default=None, ge=0)
    transport_cost: Optional[float] = Field(default=None, ge=0)
    additional_cost: Optional[float] = Field(default=None, ge=0)
    repair_time_minutes: Optional[int] = Field(default=None, ge=1)
    price_explanation: Optional[str] = None
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
    repair_time_minutes: Optional[int] = None
    diagnosis_cost: Optional[float] = None
    labor_cost: Optional[float] = None
    parts_cost: Optional[float] = None
    transport_cost: Optional[float] = None
    additional_cost: Optional[float] = None
    price_explanation: Optional[str] = None
    notes: Optional[str] = None
    status: OfferStatus
    created_at: datetime
    updated_at: datetime
    workshop: Optional['WorkshopResponse'] = None
    technician: Optional['TechnicianResponse'] = None

    class Config:
        from_attributes = True


class IncidentTrackingResponse(BaseModel):
    id: int
    incident_id: int
    technician_id: int
    latitude: float
    longitude: float
    remaining_distance_meters: Optional[int] = None
    estimated_arrival_time: Optional[int] = None
    status: IncidentStatus
    recorded_at: datetime

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


class TechnicianLocationUpdate(BaseModel):
    latitude: float
    longitude: float


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
    proof_image_url: Optional[str] = None


class IncidentCancelRequest(BaseModel):
    reason: Optional[str] = None


class IncidentCancelResponse(BaseModel):
    incident_id: int
    status: IncidentStatus
    requires_payment: bool
    message: str
    payment_id: Optional[int] = None
    payment_type: Optional[str] = None
    payment_status: Optional[str] = None
    cancellation_percentage: Optional[int] = None
    original_offer_amount_usd: Optional[float] = None
    penalty_amount_usd: Optional[float] = None
    exchange_rate_usd_to_bob: Optional[float] = None
    penalty_amount_bob: Optional[float] = None
    payment_method: Optional[PaymentMethod] = None
    qr_image_url: Optional[str] = None


class QRPaymentConfirmRequest(BaseModel):
    reference_number: str = Field(..., min_length=1)
    proof_image_url: Optional[str] = None


class QRPaymentConfirmResponse(BaseModel):
    payment_id: int
    payment_status: str
    message: str


class QRPaymentVerifyRequest(BaseModel):
    approved: bool
    notes: Optional[str] = None


class QRPaymentVerifyResponse(BaseModel):
    payment_id: int
    payment_status: str
    is_paid: bool
    message: str


class CancellationPaymentPendingResponse(BaseModel):
    payment_id: int
    incident_id: int
    client_name: Optional[str] = None
    payment_type: str
    payment_status: str
    amount_usd: float
    amount_bob: Optional[float] = None
    exchange_rate_usd_to_bob: Optional[float] = None
    reference_number: Optional[str] = None
    proof_image_url: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime


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
    status: Literal[
        "on_route",
        "in_service",
        "completed",
        "cancelled",
    ]
    reason: Optional[str] = None


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
    payment_type: Optional[str] = None
    payment_status: Optional[str] = None
    original_amount_usd: Optional[float] = None
    exchange_rate_usd_to_bob: Optional[float] = None
    amount_bob: Optional[float] = None
    proof_image_url: Optional[str] = None
    verified_at: Optional[datetime] = None
    verified_by_user_id: Optional[int] = None
    stripe_session_id: Optional[str] = None
    stripe_payment_intent_id: Optional[str] = None
    stripe_payment_status: Optional[str] = None
    currency: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class StripeCheckoutResponse(BaseModel):
    payment_id: int
    checkout_url: str
    stripe_session_id: str
    stripe_payment_status: Optional[str] = None
    currency: str


class StripeWebhookResponse(BaseModel):
    received: bool


class PaymentStatusResponse(BaseModel):
    payment_id: int
    incident_id: int
    amount: float
    is_paid: bool
    paid_at: Optional[datetime] = None
    payment_method: PaymentMethod
    payment_type: Optional[str] = None
    payment_status: Optional[str] = None
    original_amount_usd: Optional[float] = None
    exchange_rate_usd_to_bob: Optional[float] = None
    amount_bob: Optional[float] = None
    proof_image_url: Optional[str] = None
    stripe_session_id: Optional[str] = None
    stripe_payment_intent_id: Optional[str] = None
    stripe_payment_status: Optional[str] = None
    currency: Optional[str] = None
    commission_amount: float
    workshop_earnings: float


class IncidentsByStatusItem(BaseModel):
    status: IncidentStatus
    count: int


class OfferStatsResponse(BaseModel):
    offers_sent: int = 0
    offers_accepted: int = 0
    offers_rejected: int = 0
    offers_pending: int = 0


class TechnicianStatsResponse(BaseModel):
    technicians_total: int = 0
    technicians_available: int = 0
    technicians_busy: int = 0


class PaymentStatsResponse(BaseModel):
    paid_payments: int = 0
    pending_payments: int = 0
    pending_verification_payments: int = 0
    cancellation_payments_pending: int = 0


class WorkshopStatsResponse(BaseModel):
    workshop_id: int
    workshop_name: str
    total_incidents: int = 0
    active_incidents: int = 0
    completed_incidents: int = 0
    cancelled_incidents: int = 0
    incidents_by_status: dict[str, int] = Field(default_factory=dict)
    offers_sent: int = 0
    offers_accepted: int = 0
    offers_rejected: int = 0
    offers_pending: int = 0
    technicians_total: int = 0
    technicians_available: int = 0
    technicians_busy: int = 0
    paid_payments: int = 0
    pending_payments: int = 0
    pending_verification_payments: int = 0
    cancellation_payments_pending: int = 0
    total_earnings_usd: float = 0.0
    total_earnings_bob: float = 0.0
    platform_commission_usd: float = 0.0
    average_arrival_time_minutes: float = 0.0
    average_service_time_minutes: float = 0.0

    # Backward compatibility keys
    accepted_incidents: int = 0
    in_progress_incidents: int = 0
    total_technicians: int = 0
    available_technicians: int = 0


class AdminStatsResponse(BaseModel):
    total_incidents: int = 0
    active_incidents: int = 0
    completed_incidents: int = 0
    cancelled_incidents: int = 0
    incidents_by_status: dict[str, int] = Field(default_factory=dict)

    total_workshops: int = 0
    active_workshops: int = 0
    inactive_workshops: int = 0

    total_technicians: int = 0
    available_technicians: int = 0
    busy_technicians: int = 0

    total_offers: int = 0
    accepted_offers: int = 0
    rejected_offers: int = 0
    pending_offers: int = 0

    paid_payments: int = 0
    pending_payments: int = 0
    pending_verification_payments: int = 0
    cancellation_payments_pending: int = 0

    total_revenue_usd: float = 0.0
    total_revenue_bob: float = 0.0
    platform_commission_usd: float = 0.0
    workshop_earnings_usd: float = 0.0

    average_assignment_time_minutes: float = 0.0
    average_arrival_time_minutes: float = 0.0
    average_service_time_minutes: float = 0.0

    # Backward compatibility keys
    users: Optional[dict[str, Any]] = None
    workshops: Optional[dict[str, Any]] = None
    technicians: Optional[dict[str, Any]] = None
    incidents: Optional[dict[str, Any]] = None
    payments: Optional[dict[str, Any]] = None


class OperationalReportRequest(BaseModel):
    start_date: Optional[date | datetime] = None
    end_date: Optional[date | datetime] = None
    workshop_id: Optional[int] = None
    incident_type: Optional[str] = None
    status: Optional[str] = None
    technician_id: Optional[int] = None
    client_id: Optional[int] = None
    vehicle_id: Optional[int] = None
    payment_method: Optional[str] = None


class OperationalReportAppliedFilters(BaseModel):
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    workshop_id: Optional[int] = None
    incident_type: Optional[str] = None
    status: Optional[str] = None
    technician_id: Optional[int] = None
    client_id: Optional[int] = None
    vehicle_id: Optional[int] = None
    payment_method: Optional[str] = None


class OperationalReportSummary(BaseModel):
    total_incidents: int
    pending: int
    waiting_offers: int
    assigned: int
    accepted: int
    in_progress: int
    completed: int
    cancelled: int
    total_amount: float
    total_workshop_earnings: float
    total_paid: int
    total_unpaid: int


class OperationalReportItem(BaseModel):
    incident_id: int
    created_at: datetime
    updated_at: datetime
    completed_at: Optional[datetime] = None
    status: IncidentStatus
    priority: IncidentPriority
    classification: Optional[str] = None
    description: str
    location_text: Optional[str] = None
    client_id: int
    client_name: Optional[str] = None
    client_email: Optional[str] = None
    vehicle_id: Optional[int] = None
    vehicle_brand: Optional[str] = None
    vehicle_model: Optional[str] = None
    vehicle_plate: Optional[str] = None
    workshop_id: Optional[int] = None
    workshop_name: Optional[str] = None
    technician_id: Optional[int] = None
    technician_name: Optional[str] = None
    payment_id: Optional[int] = None
    payment_amount: Optional[float] = None
    payment_method: Optional[PaymentMethod] = None
    payment_is_paid: Optional[bool] = None
    commission_amount: Optional[float] = None
    workshop_earnings: Optional[float] = None


class OperationalReportResponse(BaseModel):
    role_scope: str
    applied_filters: OperationalReportAppliedFilters
    summary: OperationalReportSummary
    items: list[OperationalReportItem]


class VoiceReportParseRequest(BaseModel):
    text: str


class VoiceReportParseResponse(BaseModel):
    recognized_text: str
    filters: OperationalReportRequest
    action: Optional[str] = None
    warnings: list[str] = Field(default_factory=list)


class OfflineIncidentSyncResponse(BaseModel):
    incident: IncidentResponse
    created: bool
    idempotent: bool
    message: str


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


# CU29 Tenant admin schemas (tenant = Workshop)
class TenantWorkshopResponse(BaseModel):
    id: int
    name: str
    address: str
    latitude: float
    longitude: float
    commission_percentage: float
    is_active: bool
    owner_id: int
    owner_name: Optional[str] = None
    owner_email: Optional[str] = None
    owner_phone: Optional[str] = None
    technician_count: int = 0
    active_technician_count: int = 0
    created_at: datetime
    updated_at: datetime


class TenantWorkshopCreate(BaseModel):
    owner_id: int
    name: str = Field(..., min_length=1)
    address: str = Field(..., min_length=1)
    latitude: float
    longitude: float
    commission_percentage: float = Field(default=10.0, ge=0, le=100)
    is_active: bool = True


class TenantWorkshopOwnerCreate(BaseModel):
    full_name: str = Field(..., min_length=1)
    email: EmailStr
    phone: Optional[str] = None
    password: str = Field(..., min_length=6)


class TenantWorkshopDataCreate(BaseModel):
    name: str = Field(..., min_length=1)
    address: str = Field(..., min_length=1)
    latitude: float
    longitude: float
    commission_percentage: float = Field(default=10.0, ge=0, le=100)
    is_active: bool = True


class TenantWorkshopWithOwnerCreate(BaseModel):
    owner: TenantWorkshopOwnerCreate
    workshop: TenantWorkshopDataCreate


class TenantWorkshopUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1)
    address: Optional[str] = Field(default=None, min_length=1)
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    commission_percentage: Optional[float] = Field(default=None, ge=0, le=100)
    is_active: Optional[bool] = None


class TenantWorkshopStatusUpdate(BaseModel):
    is_active: bool


class TenantWorkshopOwnerOption(BaseModel):
    id: int
    full_name: str
    email: EmailStr
    phone: Optional[str] = None
    role: UserRole
    has_workshop: bool
    workshop_id: Optional[int] = None


class TenantWorkshopUserRow(BaseModel):
    row_type: str
    relation: str
    user_id: Optional[int] = None
    technician_id: Optional[int] = None
    workshop_id: int
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    role: UserRole
    is_active: bool
    is_available: Optional[bool] = None
    access_code: Optional[str] = None


class TenantTechnicianCreate(BaseModel):
    full_name: str = Field(..., min_length=1)
    email: EmailStr
    password: str = Field(..., min_length=6)
    phone: Optional[str] = None
    is_active: bool = True
    is_available: bool = True


class TenantTechnicianUpdate(BaseModel):
    full_name: Optional[str] = Field(default=None, min_length=1)
    phone: Optional[str] = None
    is_active: Optional[bool] = None
    is_available: Optional[bool] = None


class TenantTechnicianStatusUpdate(BaseModel):
    is_active: bool


# Resolve forward refs declared in IncidentResponse
IncidentResponse.model_rebuild()

