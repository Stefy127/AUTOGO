#!/usr/bin/env python3
import sys
import asyncio
from app.database import SessionLocal
from app import models
from app.services.mapbox_service import MapboxService
from datetime import datetime

def usage():
    print('usage: update_tech_and_regen.py <tech_id> <lat> <lng> <incident_id>')
    return 2

async def calc_and_save_route(db, incident, origin_lat, origin_lng):
    svc = MapboxService()
    try:
        res = await svc.get_distance_and_duration(origin_lat, origin_lng, incident.latitude, incident.longitude)
    except Exception as e:
        print('mapbox failed', e)
        return False
    if not res:
        print('no route result')
        return False
    incident.remaining_distance_meters = res.get('distance')
    incident.estimated_arrival_time = int(res.get('duration')) if res.get('duration') is not None else None
    incident.route_polyline = res.get('polyline')
    incident.last_eta_update_at = datetime.utcnow()
    db.add(incident)
    db.commit()
    print('saved route for incident', incident.id, 'poly length', len(incident.route_polyline) if incident.route_polyline else 0, 'eta', incident.estimated_arrival_time)
    return True


def main():
    if len(sys.argv) < 5:
        return usage()
    try:
        tech_id = int(sys.argv[1])
        lat = float(sys.argv[2])
        lng = float(sys.argv[3])
        incident_id = int(sys.argv[4])
    except Exception as e:
        print('invalid args', e)
        return usage()

    db = SessionLocal()
    tech = db.query(models.Technician).filter(models.Technician.id == tech_id).first()
    if not tech:
        print('technician not found')
        return 1

    # update tech coords
    tech.current_latitude = lat
    tech.current_longitude = lng
    db.add(tech)
    db.commit()
    print('updated technician', tech.id, 'coords to', lat, lng)

    incident = db.query(models.Incident).filter(models.Incident.id == incident_id).first()
    if not incident:
        print('incident not found')
        return 1

    # ensure incident coords present
    if incident.latitude is None or incident.longitude is None:
        print('incident missing coords, abort')
        return 1

    # calculate route from technician current coords
    ok = asyncio.run(calc_and_save_route(db, incident, lat, lng))
    if not ok:
        return 1

    # print a brief extract
    print('incident', incident.id, 'now eta_s', incident.estimated_arrival_time, 'distance_m', incident.remaining_distance_meters)
    return 0

if __name__ == '__main__':
    sys.exit(main())
