#!/usr/bin/env python3
import sys
from app.database import SessionLocal
from app import models

# decode polyline precision 5
def decode_polyline(encoded):
    coords = []
    index = 0
    lat = 0
    lng = 0
    length = len(encoded)
    while index < length:
        result = 1
        shift = 0
        result = 0
        while True:
            b = ord(encoded[index]) - 63
            index += 1
            result |= (b & 0x1f) << shift
            shift += 5
            if b < 0x20:
                break
        dlat = ~(result >> 1) if (result & 1) else (result >> 1)
        lat += dlat

        result = 0
        shift = 0
        while True:
            b = ord(encoded[index]) - 63
            index += 1
            result |= (b & 0x1f) << shift
            shift += 5
            if b < 0x20:
                break
        dlng = ~(result >> 1) if (result & 1) else (result >> 1)
        lng += dlng

        coords.append((lat / 1e5, lng / 1e5))
    return coords


def main():
    if len(sys.argv) < 2:
        print('usage: inspect_incident.py <incident_id>')
        return 2
    try:
        incident_id = int(sys.argv[1])
    except Exception:
        print('invalid id')
        return 2

    db = SessionLocal()
    incident = db.query(models.Incident).filter(models.Incident.id == incident_id).first()
    if not incident:
        print('incident not found')
        return 1
    tech = None
    if incident.technician_id:
        tech = db.query(models.Technician).filter(models.Technician.id == incident.technician_id).first()

    print('incident id:', incident.id)
    print('incident coords:', incident.latitude, incident.longitude)
    print('location_text:', incident.location_text)
    if tech:
        print('technician id:', tech.id)
        print('technician current coords:', tech.current_latitude, tech.current_longitude)
    else:
        print('no technician assigned')
    poly = incident.route_polyline or ''
    print('route_polyline length:', len(poly))
    if poly:
        try:
            coords = decode_polyline(poly)
            print('poly points count:', len(coords))
            print('first point (lat,lng):', coords[0])
            print('last point (lat,lng):', coords[-1])
        except Exception as e:
            print('poly decode failed:', e)
    print('estimated_arrival_time (s):', incident.estimated_arrival_time)
    print('remaining_distance_meters:', incident.remaining_distance_meters)
    return 0

if __name__ == '__main__':
    sys.exit(main())
