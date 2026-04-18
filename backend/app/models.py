from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum, Text, Float, Boolean, Numeric
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.database import Base


# ==================== ENUMS ====================

class UserRole(str, enum.Enum):
    CLIENT = "client"
    WORKSHOP = "workshop"
    TECHNICIAN = "technician"
    ADMIN = "admin"


class IncidentStatus(str, enum.Enum):
    PENDING = "pending"
    ACCEPTED = "accepted"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    CANCELLED = "cancelled"


class IncidentPriority(str, enum.Enum):
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class PaymentMethod(str, enum.Enum):
    CASH = "cash"
    TRANSFER = "transfer"


class VehicleType(str, enum.Enum):
    AUTOMOVIL = "automovil"
    CAMIONETA = "camioneta"


# ==================== MODELS ====================

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    hashed_password = Column(String, nullable=False)
    full_name = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    role = Column(Enum(UserRole), default=UserRole.CLIENT, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    vehicles = relationship("Vehicle", back_populates="owner", cascade="all, delete-orphan")
    incidents = relationship("Incident", foreign_keys="Incident.user_id", back_populates="user", cascade="all, delete-orphan")
    owned_workshops = relationship("Workshop", back_populates="owner", cascade="all, delete-orphan")
    audit_logs = relationship("AuditLog", back_populates="user")


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True, index=True)
    event_type = Column(String, nullable=False, index=True)
    action = Column(String, nullable=False)
    section = Column(String, nullable=True, index=True)
    endpoint = Column(String, nullable=True)
    http_method = Column(String, nullable=True)
    details = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    # Relationships
    user = relationship("User", back_populates="audit_logs")


class Workshop(Base):
    __tablename__ = "workshops"

    id = Column(Integer, primary_key=True, index=True)
    owner_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    name = Column(String, nullable=False)
    address = Column(String, nullable=False)
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    commission_percentage = Column(Float, default=10.0, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    owner = relationship("User", back_populates="owned_workshops")
    technicians = relationship("Technician", back_populates="workshop", cascade="all, delete-orphan")
    incidents = relationship("Incident", back_populates="workshop")


class Technician(Base):
    __tablename__ = "technicians"

    id = Column(Integer, primary_key=True, index=True)
    workshop_id = Column(Integer, ForeignKey("workshops.id"), nullable=False)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    name = Column(String, nullable=False)
    phone = Column(String, nullable=True)
    is_available = Column(Boolean, default=True, nullable=False)
    current_latitude = Column(Float, nullable=True)
    current_longitude = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    workshop = relationship("Workshop", back_populates="technicians")
    assigned_incidents = relationship("Incident", back_populates="technician")


class Vehicle(Base):
    __tablename__ = "vehicles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    brand = Column(String, nullable=False)
    model = Column(String, nullable=False)
    year = Column(Integer, nullable=False)
    plate = Column(String, unique=True, index=True, nullable=False)
    color = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    owner = relationship("User", back_populates="vehicles")
    incidents = relationship("Incident", back_populates="vehicle", cascade="all, delete-orphan")


class RentalVehicle(Base):
    __tablename__ = "rental_vehicles"

    id = Column(Integer, primary_key=True, index=True)
    company_name = Column(String, nullable=False)
    vehicle_type = Column(Enum(VehicleType), nullable=False)
    vehicle_name = Column(String, nullable=False)
    characteristics = Column(Text, nullable=False)
    photo_url = Column(String, nullable=True)
    whatsapp_number = Column(String, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Incident(Base):
    __tablename__ = "incidents"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=False)
    workshop_id = Column(Integer, ForeignKey("workshops.id"), nullable=True)
    technician_id = Column(Integer, ForeignKey("technicians.id"), nullable=True)
    
    # Basic info
    description = Column(Text, nullable=False)
    status = Column(Enum(IncidentStatus), default=IncidentStatus.PENDING, nullable=False)
    priority = Column(Enum(IncidentPriority), default=IncidentPriority.MEDIUM, nullable=False)
    
    # Location
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    location_text = Column(String, nullable=True)
    
    # Media
    image_url = Column(String, nullable=True)
    audio_url = Column(String, nullable=True)
    
    # AI Analysis (estructura base)
    classification = Column(String, nullable=True)
    ai_summary = Column(Text, nullable=True)
    
    # Timing
    estimated_arrival_time = Column(Integer, nullable=True)
    accepted_at = Column(DateTime, nullable=True)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    user = relationship("User", foreign_keys=[user_id], back_populates="incidents")
    vehicle = relationship("Vehicle", back_populates="incidents")
    workshop = relationship("Workshop", back_populates="incidents")
    technician = relationship("Technician", back_populates="assigned_incidents")
    history = relationship("IncidentHistory", back_populates="incident", cascade="all, delete-orphan")
    payment = relationship("Payment", back_populates="incident", uselist=False, cascade="all, delete-orphan")


class IncidentHistory(Base):
    """Trazabilidad de cambios de estado"""
    __tablename__ = "incident_history"

    id = Column(Integer, primary_key=True, index=True)
    incident_id = Column(Integer, ForeignKey("incidents.id"), nullable=False)
    status = Column(Enum(IncidentStatus), nullable=False)
    changed_by_user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    notes = Column(Text, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow)

    # Relationships
    incident = relationship("Incident", back_populates="history")


class Payment(Base):
    """Sistema de pagos directo (sin pasarela)"""
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    incident_id = Column(Integer, ForeignKey("incidents.id"), unique=True, nullable=False)
    
    amount = Column(Numeric(10, 2), nullable=False)
    payment_method = Column(Enum(PaymentMethod), nullable=False)
    
    # Commission calculation
    commission_percentage = Column(Float, default=10.0, nullable=False)
    commission_amount = Column(Numeric(10, 2), nullable=False)
    workshop_earnings = Column(Numeric(10, 2), nullable=False)
    
    # Payment tracking
    paid_at = Column(DateTime, nullable=True)
    is_paid = Column(Boolean, default=False, nullable=False)
    
    # Optional payment reference
    reference_number = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    incident = relationship("Incident", back_populates="payment")
