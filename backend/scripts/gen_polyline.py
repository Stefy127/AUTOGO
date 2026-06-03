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
    workshop = db.query(models.Workshop).filter(models.Workshop.id == incident.workshop_id).first()
    if not workshop:
        print("workshop not found")
        return 1
    svc = MapboxService()
    try:
        res = asyncio.run(svc.get_distance_and_duration(workshop.latitude, workshop.longitude, incident.latitude, incident.longitude))
    except Exception as e:
        print("mapbox call failed:", str(e))
        return 1
    print("mapbox result keys:", list(res.keys()) if res else None)
    if res and res.get('polyline'):
        incident.route_polyline = res.get('polyline')
    if res and res.get('duration'):
        try:
            incident.estimated_arrival_time = int(res.get('duration'))
        except Exception:
            pass
    db.add(incident)
    db.commit()
    print('saved route_polyline:', bool(incident.route_polyline))
    print('estimated_arrival_time:', incident.estimated_arrival_time)
    return 0

if __name__ == '__main__':
    sys.exit(main())
