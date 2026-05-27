from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.auth import get_current_user
from app import models, schemas
from app.services.mapbox_service import MapboxService
from app.services.notification_service import create_notification

router = APIRouter(prefix="/offers", tags=["offers"])
mapbox_service = MapboxService()


@router.post("", response_model=schemas.OfferResponse, status_code=status.HTTP_201_CREATED)
async def create_offer(
    offer_data: schemas.OfferCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only workshops can create offers"
        )

    workshop = db.query(models.Workshop).filter(
        models.Workshop.owner_id == current_user.id
    ).first()
    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Workshop profile not found"
        )

    incident = db.query(models.Incident).filter(
        models.Incident.id == offer_data.incident_id
    ).first()
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found"
        )

    if incident.workshop_id is not None or incident.status in [
        models.IncidentStatus.ASSIGNED,
        models.IncidentStatus.ACCEPTED,
        models.IncidentStatus.IN_PROGRESS,
        models.IncidentStatus.COMPLETED,
        models.IncidentStatus.CANCELLED,
    ]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incident is no longer available for offers"
        )

    existing_offer = db.query(models.Offer).filter(
        models.Offer.incident_id == offer_data.incident_id,
        models.Offer.workshop_id == workshop.id,
        models.Offer.status == models.OfferStatus.PENDING
    ).first()
    if existing_offer:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="You already submitted a pending offer for this incident"
        )

    selected_technician_id = offer_data.technician_id
    if selected_technician_id is not None:
        technician = db.query(models.Technician).filter(
            models.Technician.id == selected_technician_id,
            models.Technician.workshop_id == workshop.id
        ).first()
        if not technician:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Technician not found in your workshop"
            )

    estimated_arrival_time = offer_data.estimated_arrival_time
    if (
        estimated_arrival_time is None
        and workshop.latitude is not None
        and workshop.longitude is not None
        and incident.latitude is not None
        and incident.longitude is not None
    ):
        distance_info = await mapbox_service.get_distance_and_duration(
            workshop.latitude,
            workshop.longitude,
            incident.latitude,
            incident.longitude
        )
        if distance_info:
            estimated_arrival_time = int(distance_info.get("duration_minutes", 0)) + 5

    offer = models.Offer(
        incident_id=incident.id,
        workshop_id=workshop.id,
        technician_id=selected_technician_id,
        amount=offer_data.amount,
        estimated_arrival_time=estimated_arrival_time,
        notes=offer_data.notes,
        status=models.OfferStatus.PENDING
    )
    db.add(offer)

    if incident.status == models.IncidentStatus.PENDING:
        incident.status = models.IncidentStatus.WAITING_OFFERS
        db.add(models.IncidentHistory(
            incident_id=incident.id,
            status=models.IncidentStatus.WAITING_OFFERS,
            changed_by_user_id=current_user.id,
            notes="Incidente abierto a ofertas de talleres"
        ))

    db.add(models.IncidentHistory(
        incident_id=incident.id,
        status=incident.status,
        changed_by_user_id=current_user.id,
        notes=f"Oferta enviada por taller {workshop.name}"
    ))

    create_notification(
        db,
        user_id=incident.user_id,
        incident_id=incident.id,
        title="Nueva oferta recibida",
        message=f"{workshop.name} envio una oferta de ${float(offer_data.amount):.2f} para tu emergencia.",
        notification_type="offer_received",
    )

    db.commit()
    db.refresh(offer)

    return db.query(models.Offer).options(
        joinedload(models.Offer.workshop),
        joinedload(models.Offer.technician)
    ).filter(models.Offer.id == offer.id).first()


@router.post("/{offer_id}/accept", response_model=schemas.OfferResponse)
async def accept_offer(
    offer_id: int,
    accept_data: schemas.OfferAccept,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    if current_user.role != models.UserRole.CLIENT:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only clients can accept offers"
        )

    offer = db.query(models.Offer).options(
        joinedload(models.Offer.incident),
        joinedload(models.Offer.workshop)
    ).filter(models.Offer.id == offer_id).first()
    if not offer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Offer not found"
        )

    incident = offer.incident
    if incident.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to accept offers for this incident"
        )

    if incident.status not in [models.IncidentStatus.PENDING, models.IncidentStatus.WAITING_OFFERS]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incident no longer accepts offers"
        )

    if offer.status != models.OfferStatus.PENDING:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Offer is not pending"
        )

    selected_technician_id = accept_data.technician_id or offer.technician_id
    if selected_technician_id is not None:
        technician = db.query(models.Technician).filter(
            models.Technician.id == selected_technician_id,
            models.Technician.workshop_id == offer.workshop_id
        ).first()
        if not technician:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Technician not found in selected workshop"
            )
        if not technician.is_available:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Selected technician is not available"
            )
        technician.is_available = False
        offer.technician_id = selected_technician_id

    offer.status = models.OfferStatus.ACCEPTED

    db.query(models.Offer).filter(
        models.Offer.incident_id == incident.id,
        models.Offer.id != offer.id,
        models.Offer.status == models.OfferStatus.PENDING
    ).update({models.Offer.status: models.OfferStatus.REJECTED}, synchronize_session=False)

    incident.workshop_id = offer.workshop_id
    incident.technician_id = offer.technician_id
    incident.status = models.IncidentStatus.ASSIGNED
    incident.accepted_at = datetime.utcnow()
    incident.estimated_arrival_time = offer.estimated_arrival_time

    existing_payment = db.query(models.Payment).filter(
        models.Payment.incident_id == incident.id
    ).first()
    if not existing_payment:
        offer_amount = float(offer.amount)
        commission_rate = (offer.workshop.commission_percentage or 10.0) / 100.0
        commission_amount = offer_amount * commission_rate
        workshop_earnings = offer_amount - commission_amount

        payment = models.Payment(
            incident_id=incident.id,
            amount=offer_amount,
            payment_method=models.PaymentMethod.CASH,
            commission_percentage=commission_rate,
            commission_amount=commission_amount,
            workshop_earnings=workshop_earnings,
            is_paid=False
        )
        db.add(payment)

    db.add(models.IncidentHistory(
        incident_id=incident.id,
        status=models.IncidentStatus.ASSIGNED,
        changed_by_user_id=current_user.id,
        notes=f"Oferta {offer.id} aceptada por cliente"
    ))

    create_notification(
        db,
        user_id=offer.workshop.owner_id,
        incident_id=incident.id,
        title="Servicio aceptado por el cliente",
        message=f"El cliente acepto tu oferta para la emergencia #{incident.id}.",
        notification_type="service_accepted_by_client",
    )

    db.commit()

    return db.query(models.Offer).options(
        joinedload(models.Offer.workshop),
        joinedload(models.Offer.technician)
    ).filter(models.Offer.id == offer.id).first()
