#!/usr/bin/env python3
import asyncio
import sys
from app.database import SessionLocal
from app import models
from app.services.mapbox_service import MapboxService


def main():
    db = SessionLocal()
    incident = db.query(models.Incident).filter(models.Incident.id == 3).first()
    if not incident:
        print("incident not found")
        return 1
    tech = None
    if incident.technician_id:
        tech = db.query(models.Technician).filter(models.Technician.id == incident.technician_id).first()

    if tech and tech.current_latitude is not None and tech.current_longitude is not None:
        origin_lat = tech.current_latitude
        origin_lng = tech.current_longitude
        print('Using technician current coords as origin:', origin_lat, origin_lng)
    else:
        # fallback to workshop
        workshop = None
        if incident.workshop_id:
            workshop = db.query(models.Workshop).filter(models.Workshop.id == incident.workshop_id).first()
        if workshop:
            origin_lat = workshop.latitude
            origin_lng = workshop.longitude
            print('Using workshop coords as origin:', origin_lat, origin_lng)
        else:
            print('No valid origin coords found')
            return 1

    svc = MapboxService()
    try:
        res = asyncio.run(svc.get_distance_and_duration(origin_lat, origin_lng, incident.latitude, incident.longitude))
    except Exception as e:
        print('mapbox call failed:', e)
        return 1

    print('mapbox returned keys:', list(res.keys()) if res else None)
    if res and res.get('polyline'):
        incident.route_polyline = res.get('polyline')
    if res and res.get('duration'):
        try:
            incident.estimated_arrival_time = int(res.get('duration'))
        except Exception:
            pass
    db.add(incident)
    db.commit()
    print('saved route_polyline length:', len(incident.route_polyline) if incident.route_polyline else 0)
    print('estimated_arrival_time:', incident.estimated_arrival_time)
    return 0

if __name__ == '__main__':
    sys.exit(main())
