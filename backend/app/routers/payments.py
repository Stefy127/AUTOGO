from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
from decimal import Decimal

from app.database import get_db
from app.models import User, Payment, Incident, Workshop, UserRole, IncidentStatus, PaymentMethod, WorkshopPaymentQR
from app.schemas import PaymentCreate, PaymentResponse, PaymentUpdate, PaymentQRConfirm
from app.auth import get_current_user

router = APIRouter(prefix="/payments", tags=["payments"])


def calculate_commission(amount: float, commission_percentage: float):
    """
    Calcula la comisión y las ganancias del taller.
    """
    commission_amount = Decimal(str(amount)) * Decimal(str(commission_percentage)) / Decimal('100')
    workshop_earnings = Decimal(str(amount)) - commission_amount
    
    return {
        "commission_amount": float(commission_amount),
        "workshop_earnings": float(workshop_earnings)
    }


@router.post("", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
async def create_payment(
    payment_data: PaymentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Crear un registro de pago para un incidente.
    Solo puede ser creado por el taller o administrador.
    Auto-calcula la comisión y ganancias.
    """
    # Verificar permisos
    if current_user.role not in [UserRole.WORKSHOP, UserRole.ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo talleres o administradores pueden crear pagos"
        )
    
    # Verificar que el incidente existe
    incident = db.query(Incident).filter(Incident.id == payment_data.incident_id).first()
    
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incidente no encontrado"
        )
    
    # Verificar que el incidente esté completado
    if incident.status != IncidentStatus.COMPLETED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Solo se pueden registrar pagos para incidentes completados"
        )
    
    # Verificar que no exista ya un pago para este incidente
    existing_payment = db.query(Payment).filter(Payment.incident_id == payment_data.incident_id).first()
    if existing_payment:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ya existe un pago registrado para este incidente"
        )
    
    # Si el usuario es taller, verificar que el incidente le pertenece
    if current_user.role == UserRole.WORKSHOP:
        workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
        if not workshop or incident.workshop_id != workshop.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permisos para crear un pago para este incidente"
            )
    
    # Obtener la comisión del taller
    workshop = db.query(Workshop).filter(Workshop.id == incident.workshop_id).first()
    
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró el taller asociado al incidente"
        )
    
    # Calcular comisión y ganancias
    calculations = calculate_commission(payment_data.amount, workshop.commission_percentage)
    
    # Crear el pago
    new_payment = Payment(
        incident_id=payment_data.incident_id,
        amount=payment_data.amount,
        payment_method=payment_data.payment_method,
        commission_percentage=workshop.commission_percentage,
        commission_amount=calculations["commission_amount"],
        workshop_earnings=calculations["workshop_earnings"],
        reference_number=payment_data.reference_number,
        notes=payment_data.notes,
        is_paid=False
    )
    
    db.add(new_payment)
    db.commit()
    db.refresh(new_payment)
    
    return new_payment


@router.get("/{payment_id}", response_model=PaymentResponse)
async def get_payment(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener detalles de un pago.
    """
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    
    if not payment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pago no encontrado"
        )
    
    # Verificar permisos
    incident = db.query(Incident).filter(Incident.id == payment.incident_id).first()
    
    if current_user.role == UserRole.CLIENT:
        # El cliente solo puede ver sus propios pagos
        if incident.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permisos para ver este pago"
            )
    elif current_user.role == UserRole.WORKSHOP:
        # El taller solo puede ver pagos de sus incidentes
        workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
        if not workshop or incident.workshop_id != workshop.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permisos para ver este pago"
            )
    # ADMIN puede ver todos los pagos
    
    return payment


@router.patch("/{payment_id}", response_model=PaymentResponse)
async def update_payment(
    payment_id: int,
    payment_data: PaymentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Actualizar el estado de un pago (marcar como pagado).
    Solo puede ser actualizado por el taller o administrador.
    """
    # Verificar permisos
    if current_user.role not in [UserRole.WORKSHOP, UserRole.ADMIN]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo talleres o administradores pueden actualizar pagos"
        )
    
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    
    if not payment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pago no encontrado"
        )
    
    # Si el usuario es taller, verificar que el pago le pertenece
    if current_user.role == UserRole.WORKSHOP:
        incident = db.query(Incident).filter(Incident.id == payment.incident_id).first()
        workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
        
        if not workshop or incident.workshop_id != workshop.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permisos para actualizar este pago"
            )
    
    # Actualizar solo los campos proporcionados
    update_data = payment_data.dict(exclude_unset=True)
    
    # Si se marca como pagado, agregar la fecha
    if update_data.get("is_paid") and not payment.is_paid:
        update_data["paid_at"] = datetime.utcnow()
    
    for field, value in update_data.items():
        setattr(payment, field, value)
    
    db.commit()
    db.refresh(payment)
    
    return payment


@router.post("/incident/{incident_id}/pay-qr", response_model=PaymentResponse)
async def pay_incident_with_qr(
    incident_id: int,
    payment_data: PaymentQRConfirm,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != UserRole.CLIENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo clientes pueden confirmar pagos QR"
        )

    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    if not incident or incident.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incidente no encontrado"
        )

    if incident.status != IncidentStatus.COMPLETED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Solo puedes pagar incidentes completados"
        )

    payment = db.query(Payment).filter(Payment.incident_id == incident_id).first()
    if not payment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No existe un pago asociado a este incidente"
        )

    if payment.is_paid:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Este incidente ya fue pagado"
        )

    payment_qr = db.query(WorkshopPaymentQR).filter(
        WorkshopPaymentQR.workshop_id == incident.workshop_id
    ).first()
    if not payment_qr:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="El taller no tiene QR configurado"
        )

    payment.payment_method = PaymentMethod.QR
    payment.reference_number = payment_data.reference_number or f"AG-QR-{incident_id}-{int(datetime.utcnow().timestamp())}"
    payment.is_paid = True
    payment.paid_at = datetime.utcnow()
    payment.notes = "Pago QR confirmado por cliente"

    db.commit()
    db.refresh(payment)
    return payment


@router.get("/incident/{incident_id}", response_model=PaymentResponse)
async def get_payment_by_incident(
    incident_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener el pago asociado a un incidente.
    """
    payment = db.query(Payment).filter(Payment.incident_id == incident_id).first()
    
    if not payment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No se encontró un pago para este incidente"
        )
    
    # Verificar permisos
    incident = db.query(Incident).filter(Incident.id == incident_id).first()
    
    if current_user.role == UserRole.CLIENT:
        # El cliente solo puede ver sus propios pagos
        if incident.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permisos para ver este pago"
            )
    elif current_user.role == UserRole.WORKSHOP:
        # El taller solo puede ver pagos de sus incidentes
        workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
        if not workshop or incident.workshop_id != workshop.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permisos para ver este pago"
            )
    # ADMIN puede ver todos los pagos
    
    return payment


@router.get("", response_model=List[PaymentResponse])
async def get_payments(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Obtener lista de pagos.
    - ADMIN: Todos los pagos
    - WORKSHOP: Solo pagos de sus incidentes
    - CLIENT: Solo sus propios pagos
    """
    if current_user.role == UserRole.ADMIN:
        # Admin puede ver todos los pagos
        payments = db.query(Payment).offset(skip).limit(limit).all()
    elif current_user.role == UserRole.WORKSHOP:
        # Taller solo ve pagos de sus incidentes
        workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
        
        if not workshop:
            return []
        
        # Obtener IDs de incidentes del taller
        incident_ids = db.query(Incident.id).filter(Incident.workshop_id == workshop.id).all()
        incident_ids = [i[0] for i in incident_ids]
        
        payments = db.query(Payment).filter(
            Payment.incident_id.in_(incident_ids)
        ).offset(skip).limit(limit).all()
    else:
        # Cliente solo ve sus propios pagos
        # Obtener IDs de incidentes del cliente
        incident_ids = db.query(Incident.id).filter(Incident.user_id == current_user.id).all()
        incident_ids = [i[0] for i in incident_ids]
        
        payments = db.query(Payment).filter(
            Payment.incident_id.in_(incident_ids)
        ).offset(skip).limit(limit).all()
    
    return payments
