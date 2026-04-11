# 🎯 AutoGo CICLO 2 - Quick Reference

## ✅ What's Ready
- ✅ Models: Workshop, Technician, Payment, IncidentHistory
- ✅ Services: MapboxService, AIService, AssignmentService
- ✅ Environment: Mapbox API key configured

## 🚧 What's Pending
- 🔲 schemas.py (update with new models)
- 🔲 routers/workshops.py
- 🔲 routers/payments.py
- 🔲 routers/admin.py
- 🔲 Update main.py
- 🔲 Frontend integration

## 🔑 Key Files
```
backend/app/
├── models.py                 ✅ Updated
├── schemas.py                🚧 Need to update
├── services/
│   ├── mapbox_service.py     ✅ Complete
│   ├── ai_service.py         ✅ Complete
│   └── assignment_service.py ✅ Complete
└── routers/
    ├── workshops.py          🚧 Need to create
    ├── payments.py           🚧 Need to create
    └── admin.py              🚧 Need to create
```

## 📡 New Endpoints Template

### Workshops Router
```python
# GET /workshops/incidents/available
# POST /workshops/incidents/{id}/accept
# POST /workshops
# GET /workshops/stats
```

### Payments Router
```python
# POST /payments
# GET /payments/{id}
# PATCH /payments/{id}
```

### Admin Router
```python
# GET /admin/workshops
# GET /admin/incidents
# GET /admin/history
```

## 🧪 Quick Tests

### Test Mapbox Service
```python
from app.services.mapbox_service import mapbox_service

# Test geocoding
coords = await mapbox_service.geocode_address("Reforma 222, CDMX")
print(coords)  # Should return (lat, lng)

# Test distance
result = await mapbox_service.get_distance_and_duration(
    19.4326, -99.1332,  # CDMX
    19.4270, -99.1687   # Chapultepec
)
print(result)  # Should return distance, duration, geometry
```

### Test AI Service
```python
from app.services.ai_service import ai_service

result = await ai_service.process_incident_creation(
    description="Llanta ponchada en autopista",
    image_url=None,
    audio_url=None
)
print(result)  # Should return classification, priority, summary
```

## 🐳 Docker Commands
```bash
# Recreate everything
docker-compose down -v && docker-compose up --build

# View logs
docker-compose logs -f backend

# Enter backend container
docker exec -it autogo_backend bash

# Check DB
docker exec -it autogo_postgres psql -U autogo -d autogo_db
```

## 📊 Database Schema

### New Tables
- `workshops` - Taller info with geolocation
- `technicians` - Técnicos con disponibilidad
- `payments` - Pagos y comisiones
- `incident_history` - Audit trail

### Updated Tables
- `incidents` - Added 15+ new fields
- `users` - Added TECHNICIAN role

## 🎨 Frontend Integration

### Angular (Web)
```bash
cd frontend
npm install mapbox-gl @types/mapbox-gl
# Update environment.ts with Mapbox token
```

### Flutter (Mobile)
```bash
cd movile_front
# Add to pubspec.yaml:
# mapbox_gl: ^0.16.0
# geolocator: ^10.1.0
flutter pub get
```

## 🔒 RBAC Rules
- CLIENT: Ver solo sus incidentes
- WORKSHOP: Ver solo incidentes asignados a su taller
- TECHNICIAN: Ver solo incidentes asignados a él
- ADMIN: Ver TODO

## 💰 Payment Logic
```python
amount = 1000.00
commission = amount * 0.10  # 100.00
workshop_earnings = amount - commission  # 900.00
```

## 📝 Next Immediate Step
**Update schemas.py** - See CICLO2_IMPLEMENTATION_GUIDE.md section 4
