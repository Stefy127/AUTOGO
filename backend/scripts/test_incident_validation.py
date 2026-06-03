"""Test script para validar la lógica de creación de incidentes sin arrancar el servidor.
Ejecutar desde la carpeta `backend`:

    python scripts/test_incident_validation.py

Esto crea dos payloads y aplica la misma validación que el router: requiere `location_selected` true y lat/lng no nulos.
"""
import sys
from pathlib import Path
from pprint import pprint

# Ensure `backend` folder is on sys.path so `app` package can be imported
base = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(base))

try:
    from app import schemas
except Exception as e:
    print("Error importando app.schemas:", e)
    sys.exit(2)


def validate_incident_payload(payload):
    try:
        incident = schemas.IncidentCreate.parse_obj(payload)
    except Exception as e:
        return {"valid": False, "error": f"Pydantic parse error: {e}"}

    # La misma regla aplicada en backend/app/routers/incidents.py
    if not getattr(incident, 'location_selected', False) or incident.latitude is None or incident.longitude is None:
        return {"valid": False, "error": "Client must provide a fixed location (latitude and longitude)"}

    return {"valid": True, "latitude": incident.latitude, "longitude": incident.longitude}


def main():
    payload_ok = {
        "description": "Auto detenido en la vía, llanta ponchada",
        "vehicle_id": 1,
        "location_text": "",
        "location_selected": True,
        "latitude": -34.603722,
        "longitude": -58.381592,
    }

    payload_missing_location = {
        "description": "Auto detenido en la vía, llanta ponchada",
        "vehicle_id": 1,
        "location_text": "Cerca de la avenida",
        "location_selected": False,
        "latitude": None,
        "longitude": None,
    }

    print("--- Valid payload ---")
    pprint(validate_incident_payload(payload_ok))

    print("\n--- Missing location payload ---")
    pprint(validate_incident_payload(payload_missing_location))


if __name__ == '__main__':
    main()
