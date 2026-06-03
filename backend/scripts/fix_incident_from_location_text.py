#!/usr/bin/env python3
import asyncio
import sys
from app.database import SessionLocal
from app import models
from app.services.mapbox_service import MapboxService


def parse_location_text(s):
    if not s:
        return None
    parts = s.split(',')
    if len(parts) < 2:
        return None
    try:
        lat = float(parts[0].strip())
        lng = float(parts[1].strip())
        return lat, lng
    except Exception:
        return None


def main(incident_id=4):
    db = SessionLocal()
    incident = db.query(models.Incident).filter(models.Incident.id == incident_id).first()
    if not incident:
        print('incident not found')
        return 1

    parsed = parse_location_text(incident.location_text)
    if parsed:
        lat, lng = parsed
        print('parsed location_text ->', lat, lng)
        incident.latitude = lat
        incident.longitude = lng
    else:
        print('no valid location_text')

    # choose origin: prefer workshop coords
    origin_lat = None
    origin_lng = None
    if incident.workshop and incident.workshop.latitude is not None and incident.workshop.longitude is not None:
        origin_lat = incident.workshop.latitude
        origin_lng = incident.workshop.longitude
        print('using workshop as origin:', origin_lat, origin_lng)

    if origin_lat is None or incident.latitude is None or incident.longitude is None:
        print('missing coords to compute route')
        db.add(incident)
        db.commit()
        return 1

    svc = MapboxService()
    try:
        res = asyncio.run(svc.get_distance_and_duration(origin_lat, origin_lng, incident.latitude, incident.longitude))
    except Exception as e:
        print('mapbox failed', e)
        res = None

    if res:
        incident.remaining_distance_meters = res.get('distance')
        incident.estimated_arrival_time = int(res.get('duration')) if res.get('duration') is not None else None
        incident.route_polyline = res.get('polyline')
        incident.last_eta_update_at = models.datetime.utcnow() if hasattr(models, 'datetime') else None
        print('saved polyline length:', len(incident.route_polyline) if incident.route_polyline else 0)
        print('eta s:', incident.estimated_arrival_time)
    else:
        print('no route result')

    db.add(incident)
    db.commit()
    return 0

if __name__ == '__main__':
    sys.exit(main())
