from fastapi import APIRouter, Depends, HTTPException, status, Request
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
from decimal import Decimal, ROUND_HALF_UP
from urllib.parse import urlparse, parse_qsl, urlencode, urlunparse
import json
import stripe

from app.database import get_db
from app.models import User, Payment, Incident, Workshop, UserRole, IncidentStatus, PaymentMethod, WorkshopPaymentQR
from app.schemas import (
    PaymentCreate,
    PaymentResponse,
    PaymentUpdate,
    PaymentQRConfirm,
    StripeCheckoutResponse,
    StripeWebhookResponse,
    PaymentStatusResponse,
)
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
    if parsed.fragment:
        fragment_path, _, fragment_query = parsed.fragment.partition("?")
        current_fragment_query = dict(parse_qsl(fragment_query, keep_blank_values=True))
        current_fragment_query.update(params)
        new_fragment = f"{fragment_path}?{urlencode(current_fragment_query)}"
        return urlunparse(parsed._replace(fragment=new_fragment))

    current = dict(parse_qsl(parsed.query, keep_blank_values=True))
    current.update(params)
    return urlunparse(parsed._replace(query=urlencode(current)))


def _get_payment_with_incident_or_404(db: Session, payment_id: int):
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
    return payment, incident


def _assert_payment_visibility(payment: Payment, incident: Incident, current_user: User, db: Session):
    if current_user.role == UserRole.CLIENT:
        if incident.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permisos para ver este pago"
            )
    elif current_user.role == UserRole.WORKSHOP:
        workshop = db.query(Workshop).filter(Workshop.owner_id == current_user.id).first()
        if not workshop or incident.workshop_id != workshop.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permisos para ver este pago"
            )


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


@router.post("/stripe/webhook", response_model=StripeWebhookResponse)
async def stripe_webhook(
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Webhook Stripe para confirmar pagos de Checkout.
    """
    if not settings.STRIPE_WEBHOOK_SECRET:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Stripe webhook no configurado: falta STRIPE_WEBHOOK_SECRET"
        )

    payload = await request.body()
    signature = request.headers.get("stripe-signature")

    try:
        stripe.Webhook.construct_event(
            payload=payload,
            sig_header=signature,
            secret=settings.STRIPE_WEBHOOK_SECRET,
        )
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Payload inválido de Stripe"
        )
    except stripe.error.SignatureVerificationError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Firma inválida de Stripe webhook"
        )

    event = json.loads(payload.decode("utf-8"))
    event_type = event.get("type")
    if event_type not in [
        "checkout.session.completed",
        "checkout.session.async_payment_failed",
        "checkout.session.expired",
    ]:
        return {"received": True, "ignored": event_type}

    session = event.get("data", {}).get("object", {}) or {}
    metadata = session.get("metadata", {}) or {}
    payment_id = metadata.get("payment_id")
    session_id = session.get("id")
    payment_status = session.get("payment_status")
    payment_intent = session.get("payment_intent")

    payment = None
    if payment_id:
        try:
            payment_id_int = int(payment_id)
        except (TypeError, ValueError):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="metadata.payment_id inválido en webhook Stripe"
            )
        payment = db.query(Payment).filter(Payment.id == payment_id_int).first()
    elif session_id:
        payment = db.query(Payment).filter(Payment.stripe_session_id == session_id).first()

    if event_type == "checkout.session.completed":
        if not payment:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No se encontró el pago asociado al webhook"
            )

        if payment.stripe_session_id and session_id and payment.stripe_session_id != session_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Inconsistencia de sesión Stripe para el pago"
            )

        if payment.is_paid:
            return StripeWebhookResponse(received=True)

        payment.stripe_payment_status = payment_status or "completed"
        if payment_intent:
            payment.stripe_payment_intent_id = str(payment_intent)
        if session_id:
            payment.stripe_session_id = str(session_id)

        if (payment_status or "").lower() == "paid":
            payment.is_paid = True
            payment.paid_at = datetime.utcnow()
            payment.payment_method = PaymentMethod.TRANSFER
            payment.reference_number = str(payment_intent) if payment_intent else payment.reference_number
            payment.notes = "Pago confirmado por Stripe Checkout"
            payment.updated_at = datetime.utcnow()

            incident = db.query(Incident).filter(Incident.id == payment.incident_id).first()
            if incident:
                incident.payment_method = PaymentMethod.TRANSFER

        db.commit()
        return StripeWebhookResponse(received=True)

    if event_type in ["checkout.session.async_payment_failed", "checkout.session.expired"]:
        if payment:
            fallback_status = "async_payment_failed" if event_type.endswith("failed") else "expired"
            payment.stripe_payment_status = payment_status or fallback_status
            if session_id and not payment.stripe_session_id:
                payment.stripe_session_id = str(session_id)
            db.commit()
        return StripeWebhookResponse(received=True)

    return StripeWebhookResponse(received=True)


@router.get("/{payment_id}/status", response_model=PaymentStatusResponse)
async def get_payment_status(
    payment_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    payment, incident = _get_payment_with_incident_or_404(db, payment_id)
    _assert_payment_visibility(payment, incident, current_user, db)

    return PaymentStatusResponse(
        payment_id=payment.id,
        incident_id=payment.incident_id,
        amount=float(payment.amount),
        is_paid=payment.is_paid,
        paid_at=payment.paid_at,
        payment_method=payment.payment_method,
        stripe_session_id=payment.stripe_session_id,
        stripe_payment_intent_id=payment.stripe_payment_intent_id,
        stripe_payment_status=payment.stripe_payment_status,
        currency=payment.currency,
        commission_amount=float(payment.commission_amount),
        workshop_earnings=float(payment.workshop_earnings),
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
