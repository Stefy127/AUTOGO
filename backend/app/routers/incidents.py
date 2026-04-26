from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
from datetime import datetime
from app.database import get_db
from app import models, schemas
from app.auth import get_current_active_user
from app.services.ai_service import AIService
from app.services.mapbox_service import MapboxService
import os

router = APIRouter(prefix="/incidents", tags=["Incidents"])

# Initialize services
ai_service = AIService()
mapbox_service = MapboxService()


@router.post("", response_model=schemas.IncidentResponse, status_code=status.HTTP_201_CREATED)
async def create_incident(
    incident: schemas.IncidentCreate,
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Crear un nuevo incidente con procesamiento de IA y auto-asignación.
    """
    # Verify that the vehicle belongs to the user
    vehicle = db.query(models.Vehicle).filter(
        models.Vehicle.id == incident.vehicle_id,
        models.Vehicle.user_id == current_user.id
    ).first()
    
    if not vehicle:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Vehicle not found or does not belong to you"
        )
    
    # Create base incident data
    incident_data = incident.dict()
    incident_data["user_id"] = current_user.id
    
    # Process with AI if enabled
    ai_enabled = os.getenv("AI_ENABLED", "false").lower() == "true"
    
    if ai_enabled:
        ai_result = await ai_service.process_incident_creation(
            description=incident.description,
            image_url=incident.image_url,
            audio_url=incident.audio_url
        )
        
        # Add AI results to incident data
        if ai_result:
            incident_data["classification"] = ai_result.get("classification")
            incident_data["priority"] = ai_result.get("priority", models.IncidentPriority.MEDIUM)
            incident_data["ai_summary"] = ai_result.get("ai_summary")
    else:
        # Default priority if AI disabled
        incident_data["priority"] = models.IncidentPriority.MEDIUM
    
    # Geocode address if location text provided but no coordinates
    if incident.location_text and (not incident.latitude or not incident.longitude or incident.latitude == 0.0 or incident.longitude == 0.0):
        geocode_result = await mapbox_service.geocode_address(incident.location_text)
        if geocode_result:
            incident_data["latitude"] = geocode_result[0]
            incident_data["longitude"] = geocode_result[1]
    
    # Create incident
    db_incident = models.Incident(**incident_data)
    db.add(db_incident)
    db.commit()
    db.refresh(db_incident)
    
    # Create history entry
    history = models.IncidentHistory(
        incident_id=db_incident.id,
        status=models.IncidentStatus.PENDING,
        changed_by_user_id=current_user.id,
        notes="Incidente creado"
    )
    db.add(history)
    db.commit()
    
    # Load relationships for response
    db.refresh(db_incident)
    return db_incident


@router.get("", response_model=List[schemas.IncidentResponse])
def get_incidents(
    status: Optional[str] = None,
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Obtener incidentes según el rol del usuario.
    - CLIENT: Solo sus propios incidentes
    - WORKSHOP: Incidentes asignados a su taller
    - ADMIN: Todos los incidentes
    """
    query = db.query(models.Incident).options(
        joinedload(models.Incident.user),
        joinedload(models.Incident.vehicle),
        joinedload(models.Incident.workshop),
        joinedload(models.Incident.technician),
        joinedload(models.Incident.payment),
        joinedload(models.Incident.offers).joinedload(models.Offer.workshop),
        joinedload(models.Incident.offers).joinedload(models.Offer.technician)
    )
    
    if current_user.role == models.UserRole.CLIENT:
        # Clients only see their own incidents
        query = query.filter(models.Incident.user_id == current_user.id)
    elif current_user.role == models.UserRole.WORKSHOP:
        # Workshops only see incidents assigned to them
        workshop = db.query(models.Workshop).filter(
            models.Workshop.owner_id == current_user.id
        ).first()
        
        if workshop:
            query = query.filter(models.Incident.workshop_id == workshop.id)
        else:
            # Si no tiene taller, no ve nada
            return []
    # ADMIN sees all incidents
    
    # Filter by status if provided
    if status:
        query = query.filter(models.Incident.status == status)
    
    incidents = query.order_by(models.Incident.created_at.desc()).all()
    return incidents


@router.get("/available", response_model=List[schemas.IncidentResponse])
def get_available_incidents_for_workshops(
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Incidentes visibles para talleres en modo marketplace.
    Solo talleres: incidentes pendientes o esperando ofertas y sin asignación final.
    """
    if current_user.role != models.UserRole.WORKSHOP:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only workshops can access available incidents"
        )

    workshop = db.query(models.Workshop).filter(
        models.Workshop.owner_id == current_user.id
    ).first()

    if not workshop:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Workshop profile not found"
        )

    incidents = db.query(models.Incident).options(
        joinedload(models.Incident.user),
        joinedload(models.Incident.vehicle),
        joinedload(models.Incident.offers)
    ).filter(
        models.Incident.workshop_id.is_(None),
        models.Incident.status.in_([
            models.IncidentStatus.PENDING,
            models.IncidentStatus.WAITING_OFFERS
        ])
    ).order_by(models.Incident.created_at.desc()).all()

    return incidents


@router.get("/{incident_id}/offers", response_model=List[schemas.OfferResponse])
def get_incident_offers(
    incident_id: int,
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Lista ofertas de un incidente. Cliente solo puede ver las de sus incidentes.
    """
    incident = db.query(models.Incident).filter(
        models.Incident.id == incident_id
    ).first()

    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found"
        )

    if current_user.role == models.UserRole.CLIENT and incident.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view offers for this incident"
        )

    if current_user.role == models.UserRole.WORKSHOP:
        workshop = db.query(models.Workshop).filter(
            models.Workshop.owner_id == current_user.id
        ).first()

        if not workshop:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Workshop profile not found"
            )

        offers = db.query(models.Offer).options(
            joinedload(models.Offer.workshop),
            joinedload(models.Offer.technician)
        ).filter(
            models.Offer.incident_id == incident_id,
            models.Offer.workshop_id == workshop.id
        ).order_by(models.Offer.created_at.desc()).all()
        return offers

    offers = db.query(models.Offer).options(
        joinedload(models.Offer.workshop),
        joinedload(models.Offer.technician)
    ).filter(
        models.Offer.incident_id == incident_id
    ).order_by(models.Offer.created_at.desc()).all()

    return offers


@router.get("/{incident_id}", response_model=schemas.IncidentResponse)
def get_incident(
    incident_id: int,
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    incident = db.query(models.Incident).options(
        joinedload(models.Incident.user),
        joinedload(models.Incident.vehicle),
        joinedload(models.Incident.workshop),
        joinedload(models.Incident.technician),
        joinedload(models.Incident.payment),
        joinedload(models.Incident.offers).joinedload(models.Offer.workshop),
        joinedload(models.Incident.offers).joinedload(models.Offer.technician)
    ).filter(
        models.Incident.id == incident_id
    ).first()
    
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found"
        )
    
    # Check permissions
    if current_user.role == models.UserRole.CLIENT and incident.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this incident"
        )
    
    return incident


@router.patch("/{incident_id}", response_model=schemas.IncidentResponse)
def update_incident(
    incident_id: int,
    incident_update: schemas.IncidentUpdate,
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Actualizar un incidente con registro de historial.
    """
    incident = db.query(models.Incident).filter(
        models.Incident.id == incident_id
    ).first()
    
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found"
        )
    
    # Check permissions based on role
    if current_user.role == models.UserRole.CLIENT:
        # Clients can only update their own incidents and only limited fields
        if incident.user_id != current_user.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized to update this incident"
            )
        # Clients can only cancel their own incidents
        if incident_update.status and incident_update.status != models.IncidentStatus.CANCELLED:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Clients can only cancel incidents"
            )
    elif current_user.role == models.UserRole.WORKSHOP:
        # Workshop can only update incidents assigned to them
        workshop = db.query(models.Workshop).filter(
            models.Workshop.owner_id == current_user.id
        ).first()
        
        if not workshop or incident.workshop_id != workshop.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized to update this incident"
            )
    # ADMIN can update any incident
    
    # Store old values for history and availability updates
    old_status = incident.status
    old_technician_id = incident.technician_id
    
    # Update fields
    update_data = incident_update.dict(exclude_unset=True)
    
    # Update timestamps based on status changes
    if "status" in update_data:
        new_status = update_data["status"]
        
        if new_status == models.IncidentStatus.ACCEPTED and not incident.accepted_at:
            incident.accepted_at = datetime.utcnow()
        elif new_status == models.IncidentStatus.IN_PROGRESS and not incident.started_at:
            incident.started_at = datetime.utcnow()
        elif new_status == models.IncidentStatus.COMPLETED and not incident.completed_at:
            incident.completed_at = datetime.utcnow()
            
            # Mark technician as available again
            if incident.technician_id:
                technician = db.query(models.Technician).filter(
                    models.Technician.id == incident.technician_id
                ).first()
                if technician:
                    technician.is_available = True

    # If a technician is newly assigned, mark that technician as unavailable.
    if "technician_id" in update_data and update_data["technician_id"] is not None:
        assigned_technician = db.query(models.Technician).filter(
            models.Technician.id == update_data["technician_id"]
        ).first()
        if assigned_technician:
            assigned_technician.is_available = False

    # If technician changed, release previous technician.
    if (
        "technician_id" in update_data
        and old_technician_id is not None
        and update_data["technician_id"] != old_technician_id
    ):
        previous_technician = db.query(models.Technician).filter(
            models.Technician.id == old_technician_id
        ).first()
        if previous_technician:
            previous_technician.is_available = True
    
    # Apply updates
    for field, value in update_data.items():
        setattr(incident, field, value)
    
    db.commit()
    db.refresh(incident)
    
    # Create history entry if status changed
    if "status" in update_data and old_status != incident.status:
        history = models.IncidentHistory(
            incident_id=incident_id,
            status=incident.status,
            changed_by_user_id=current_user.id,
            notes=f"Estado cambiado de {old_status} a {incident.status}"
        )
        db.add(history)
        db.commit()
    
    return incident


@router.delete("/{incident_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_incident(
    incident_id: int,
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    incident = db.query(models.Incident).filter(
        models.Incident.id == incident_id
    ).first()
    
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found"
        )
    
    # Only the owner or admin can delete
    if (current_user.role != models.UserRole.ADMIN and 
        incident.user_id != current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to delete this incident"
        )
    
    db.delete(incident)
    db.commit()
    return None


@router.get("/{incident_id}/history", response_model=List[schemas.IncidentHistoryResponse])
def get_incident_history(
    incident_id: int,
    current_user: models.User = Depends(get_current_active_user),
    db: Session = Depends(get_db)
):
    """
    Obtener el historial de cambios de un incidente.
    """
    # Verify incident exists
    incident = db.query(models.Incident).filter(
        models.Incident.id == incident_id
    ).first()
    
    if not incident:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Incident not found"
        )
    
    # Check permissions
    if current_user.role == models.UserRole.CLIENT and incident.user_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to view this incident history"
        )
    elif current_user.role == models.UserRole.WORKSHOP:
        workshop = db.query(models.Workshop).filter(
            models.Workshop.owner_id == current_user.id
        ).first()
        
        if not workshop or incident.workshop_id != workshop.id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Not authorized to view this incident history"
            )
    
    # Get history
    history = db.query(models.IncidentHistory).filter(
        models.IncidentHistory.incident_id == incident_id
    ).order_by(models.IncidentHistory.timestamp.desc()).all()
    
    return history
