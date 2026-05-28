from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from urllib.parse import urlparse, parse_qsl, urlencode, urlunparse
import stripe

from app.database import get_db
from app.models import User, Payment, Incident, Workshop, UserRole, IncidentStatus, PaymentMethod, WorkshopPaymentQR
from app.schemas import PaymentCreate, PaymentResponse, PaymentUpdate, PaymentQRConfirm, StripeCheckoutResponse
from app.auth import get_current_user
from app.config import settings

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


def _append_query_params(url: str, params: dict[str, str]) -> str:
    parsed = urlparse(url)
    current = dict(parse_qsl(parsed.query, keep_blank_values=True))
    current.update(params)
    return urlunparse(parsed._replace(query=urlencode(current)))


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


@router.post("/{payment_id}/stripe/checkout", response_model=StripeCheckoutResponse)
async def create_stripe_checkout(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Crear una sesión de Stripe Checkout para un pago pendiente existente.
    """
    if current_user.role != UserRole.CLIENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo clientes pueden crear checkout con Stripe"
        )

    if not settings.STRIPE_SECRET_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Stripe no está configurado: falta STRIPE_SECRET_KEY"
        )

    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Pago no encontrado"
        )

    incident = db.query(Incident).filter(Incident.id == payment.incident_id).first()
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incidente asociado no encontrado"
        )

    if incident.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="No tienes permisos para pagar este incidente"
        )

    if payment.is_paid:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Este pago ya fue completado"
        )

    if incident.status != IncidentStatus.COMPLETED:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Solo se puede pagar con Stripe cuando el incidente está COMPLETED"
        )

    amount_decimal = Decimal(str(payment.amount))
    if amount_decimal <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Monto de pago inválido para checkout"
        )

    unit_amount = int((amount_decimal * Decimal("100")).quantize(Decimal("1"), rounding=ROUND_HALF_UP))
    currency = (settings.STRIPE_CURRENCY or "usd").lower()

    stripe.api_key = settings.STRIPE_SECRET_KEY
    metadata = {
        "payment_id": str(payment.id),
        "incident_id": str(incident.id),
        "client_id": str(current_user.id),
    }

    success_url = _append_query_params(
        settings.STRIPE_SUCCESS_URL,
        {
            "payment_id": str(payment.id),
            "session_id": "{CHECKOUT_SESSION_ID}",
        }
    )
    cancel_url = _append_query_params(
        settings.STRIPE_CANCEL_URL,
        {
            "payment_id": str(payment.id),
            "session_id": "{CHECKOUT_SESSION_ID}",
        }
    )

    try:
        checkout_session = stripe.checkout.Session.create(
            mode="payment",
            success_url=success_url,
            cancel_url=cancel_url,
            metadata=metadata,
            payment_intent_data={"metadata": metadata},
            line_items=[
                {
                    "quantity": 1,
                    "price_data": {
                        "currency": currency,
                        "unit_amount": unit_amount,
                        "product_data": {
                            "name": f"Servicio AutoGo - Incidente #{incident.id}",
                            "description": "Pago de atención de emergencia vehicular",
                        },
                    },
                }
            ],
        )
    except stripe.error.StripeError as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error al crear checkout en Stripe: {str(exc)}"
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error inesperado al crear checkout: {str(exc)}"
        )

    payment.stripe_session_id = checkout_session.id
    payment.stripe_payment_status = checkout_session.payment_status
    payment.currency = currency

    db.commit()
    db.refresh(payment)

    return StripeCheckoutResponse(
        payment_id=payment.id,
        checkout_url=checkout_session.url,
        stripe_session_id=checkout_session.id,
        stripe_payment_status=checkout_session.payment_status,
        currency=currency,
    )


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
