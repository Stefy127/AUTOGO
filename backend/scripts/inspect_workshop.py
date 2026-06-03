#!/usr/bin/env python3
import sys
from app.database import SessionLocal
from app import models

def main():
    db = SessionLocal()
    incident = db.query(models.Incident).filter(models.Incident.id == 3).first()
    if not incident:
        print('incident not found')
        return 1
    workshop = None
    if incident.workshop_id:
        workshop = db.query(models.Workshop).filter(models.Workshop.id == incident.workshop_id).first()
    tech = None
    if incident.technician_id:
        tech = db.query(models.Technician).filter(models.Technician.id == incident.technician_id).first()
    print('incident.workshop_id:', incident.workshop_id)
    if workshop:
        print('workshop coords:', workshop.latitude, workshop.longitude)
    else:
        print('no workshop')
    if tech and tech.workshop_id:
        tw = db.query(models.Workshop).filter(models.Workshop.id == tech.workshop_id).first()
        if tw:
            print('technician.workshop coords:', tw.latitude, tw.longitude)
    return 0

if __name__ == '__main__':
    sys.exit(main())
