#!/bin/bash

echo "🚀 AutoGo CICLO 2 - Setup Helper Script"
echo "========================================"
echo ""

# Colors
GREEN='\033[0.32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check current directory
if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}❌ Error: Execute this script from the AutoGo root directory${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Location verified${NC}"
echo ""

# Step 1: Update environment variables
echo "📝 Step 1: Updating environment variables..."
if [ ! -f "backend/.env" ]; then
    cp backend/.env.example backend/.env
fi

# Add Mapbox API key if not exists
if ! grep -q "MAPBOX_API_KEY" backend/.env; then
    echo "MAPBOX_API_KEY=pk.eyJ1IjoiYW5nZWxtb3JhMzciLCJhIjoiY21uczVzemtqMGEwbTJzcTA5NGJuODk4eSJ9.N1m0wsLi4oNu-dmRDG4z1w" >> backend/.env
    echo "AI_ENABLED=false" >> backend/.env
    echo "MAX_WORKSHOP_DISTANCE_KM=50" >> backend/.env
    echo -e "${GREEN}✓ Environment variables added to backend/.env${NC}"
else
    echo -e "${YELLOW}⚠ MAPBOX_API_KEY already exists in backend/.env${NC}"
fi

# Step 2: Update requirements.txt
echo ""
echo "📦 Step 2: Updating requirements.txt..."
if ! grep -q "httpx" backend/requirements.txt; then
    echo "httpx==0.25.2" >> backend/requirements.txt
    echo -e "${GREEN}✓ httpx added to requirements.txt${NC}"
else
    echo -e "${YELLOW}⚠ httpx already in requirements.txt${NC}"
fi

# Step 3: Create necessary directories
echo ""
echo "📁 Step 3: Creating necessary directories..."
mkdir -p backend/app/routers
mkdir -p backend/app/services
mkdir -p backend/app/utils
echo -e "${GREEN}✓ Directories created${NC}"

# Step 4: Show next steps
echo ""
echo "=================================="
echo -e "${GREEN}✅ Setup completed successfully!${NC}"
echo "=================================="
echo ""
echo "📋 NEXT MANUAL STEPS:"
echo ""
echo "1️⃣  Update schemas.py:"
echo "   cd backend/app"
echo "   # Edit schemas.py with new models (see CICLO2_IMPLEMENTATION_GUIDE.md)"
echo ""
echo "2️⃣  Create router files:"
echo "   touch backend/app/routers/workshops.py"
echo "   touch backend/app/routers/payments.py"
echo "   touch backend/app/routers/admin.py"
echo ""
echo "3️⃣  Recreate database:"
echo "   docker-compose down -v"
echo "   docker-compose up --build"
echo ""
echo "4️⃣  Test Mapbox integration:"
echo "   # After backend is running"
echo "   curl http://localhost:8000/docs"
echo ""
echo "📚 Documentation:"
echo "   - Complete guide: CICLO2_IMPLEMENTATION_GUIDE.md"
echo "   - Summary: CICLO2_SUMMARY.md"
echo ""
echo "🔗 API Key configured:"
echo "   Mapbox: pk.eyJ1...4z1w"
echo ""

# Step 5: Create quick reference card
cat > QUICK_REFERENCE.md << 'EOF'
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
EOF

echo -e "${GREEN}✓ Quick reference created: QUICK_REFERENCE.md${NC}"
echo ""
echo "🎉 Ready to continue with CICLO 2 implementation!"
