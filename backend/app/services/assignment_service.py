"""
Workshop Assignment Service
Handles intelligent assignment of incidents to workshops based on:
- Distance (Mapbox API)
- Technician availability
- Incident priority
"""
from typing import List, Optional, Dict
from sqlalchemy.orm import Session
from app.models import Workshop, Technician, Incident, IncidentPriority
from app.services.mapbox_service import mapbox_service


class AssignmentService:
    def __init__(self):
        self.weights = {
            "distance": 0.5,
            "availability": 0.3,
            "priority": 0.2
        }
    
    async def find_best_workshop(
        self,
        db: Session,
        incident: Incident
    ) -> Optional[Workshop]:
        """
        Find the best workshop to handle an incident
        
        Algorithm:
            score = (distance_score * 0.5) + (availability_score * 0.3) + (priority_score * 0.2)
            Lower score is better
        
        Args:
            db: Database session
            incident: Incident object
            
        Returns:
            Best workshop or None if no workshops available
        """
        # Get all active workshops
        workshops = db.query(Workshop).filter(Workshop.is_active == True).all()
        
        if not workshops:
            return None
        
        # Calculate scores for each workshop
        workshop_scores = []
        
        for workshop in workshops:
            # Check if workshop has available technicians
            available_techs = db.query(Technician).filter(
                Technician.workshop_id == workshop.id,
                Technician.is_available == True
            ).count()
            
            if available_techs == 0:
                continue  # Skip workshops with no available technicians
            
            # Calculate distance
            distance_data = await mapbox_service.get_distance_and_duration(
                incident.latitude,
                incident.longitude,
                workshop.latitude,
                workshop.longitude
            )
            
            if not distance_data:
                continue  # Skip if can't calculate distance
            
            distance_km = distance_data["distance"] / 1000  # Convert to km
            duration_min = distance_data["duration_minutes"]
            
            # Calculate component scores
            # Distance score: normalize to 0-100 (assuming max 50km)
            distance_score = min(distance_km / 50 * 100, 100)
            
            # Availability score: more technicians = lower score (better)
            availability_score = max(0, 100 - (available_techs * 20))
            
            # Priority score: higher priority = lower acceptable distance
            priority_multiplier = {
                IncidentPriority.LOW: 1.0,
                IncidentPriority.MEDIUM: 0.8,
                IncidentPriority.HIGH: 0.5
            }
            priority_score = distance_score * priority_multiplier.get(incident.priority, 1.0)
            
            # Calculate final weighted score
            final_score = (
                distance_score * self.weights["distance"] +
                availability_score * self.weights["availability"] +
                priority_score * self.weights["priority"]
            )
            
            workshop_scores.append({
                "workshop": workshop,
                "score": final_score,
                "distance_km": distance_km,
                "duration_min": duration_min,
                "available_technicians": available_techs
            })
        
        if not workshop_scores:
            return None
        
        # Sort by score (lower is better) and return best workshop
        workshop_scores.sort(key=lambda x: x["score"])
        best_match = workshop_scores[0]
        
        # Store estimated arrival time
        incident.estimated_arrival_time = best_match["duration_min"]
        
        return best_match["workshop"]
    
    async def assign_technician(
        self,
        db: Session,
        incident: Incident,
        workshop_id: int
    ) -> Optional[Technician]:
        """
        Assign an available technician from the workshop to the incident
        
        Args:
            db: Database session
            incident: Incident object
            workshop_id: Workshop ID
            
        Returns:
            Assigned technician or None
        """
        # Get available technicians from the workshop
        available_techs = db.query(Technician).filter(
            Technician.workshop_id == workshop_id,
            Technician.is_available == True
        ).all()
        
        if not available_techs:
            return None
        
        # Simple assignment: pick first available
        # TODO: Could be enhanced with distance from technician current location
        technician = available_techs[0]
        
        # Mark technician as unavailable
        technician.is_available = False
        db.commit()
        
        return technician
    
    async def get_workshops_in_range(
        self,
        db: Session,
        latitude: float,
        longitude: float,
        max_distance_km: float = 50
    ) -> List[Dict]:
        """
        Get all workshops within a certain distance
        
        Args:
            db: Database session
            latitude: Origin latitude
            longitude: Origin longitude
            max_distance_km: Maximum distance in kilometers
            
        Returns:
            List of workshops with distance info
        """
        workshops = db.query(Workshop).filter(Workshop.is_active == True).all()
        workshops_in_range = []
        
        for workshop in workshops:
            distance_data = await mapbox_service.get_distance_and_duration(
                latitude,
                longitude,
                workshop.latitude,
                workshop.longitude
            )
            
            if distance_data:
                distance_km = distance_data["distance"] / 1000
                
                if distance_km <= max_distance_km:
                    workshops_in_range.append({
                        "workshop": workshop,
                        "distance_km": round(distance_km, 2),
                        "duration_minutes": distance_data["duration_minutes"]
                    })
        
        # Sort by distance
        workshops_in_range.sort(key=lambda x: x["distance_km"])
        
        return workshops_in_range


# Singleton instance
assignment_service = AssignmentService()
