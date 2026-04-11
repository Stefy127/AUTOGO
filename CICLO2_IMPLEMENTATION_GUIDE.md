# 📋 AUTOGO CICLO 2 - GUÍA DE IMPLEMENTACIÓN COMPLETA

## ✅ COMPLETADO

### 1. Backend - Modelos de Base de Datos
- ✅ `app/models.py` actualizado con:
  - **Workshop**: Talleres con geoloc alización
  - **Technician**: Técnicos asignados a talleres
  - **Payment**: Sistema de pagos sin pasarela
  - **IncidentHistory**: Trazabilidad de cambios
  - **Incident**: Actualizado con nuevos campos (priority, workshop_id, technician_id, classification, ai_summary, etc.)
  - **UserRole**: Agregado rol TECHNICIAN
  - **IncidentStatus**: Agregado ACCEPTED y COMPLETED
  - **New Enums**: IncidentPriority, PaymentMethod

### 2. Backend - Servicios
- ✅ `app/services/mapbox_service.py`: Integración completa con Mapbox API
  - `geocode_address()`: Convertir dirección → coordenadas
  - `reverse_geocode()`: Convertir coordenadas → dirección
  - `get_distance_and_duration()`: Calcular distancia y tiempo
  - `get_route()`: Obtener ruta completa para visualización
  
- ✅ `app/services/ai_service.py`: Estructura base para IA
  - `transcribe_audio()`: Placeholder para transcripción
  - `classify_incident()`: Clasificación basada en keywords
  - `analyze_image()`: Placeholder para análisis de imágenes
  - `generate_summary()`: Generación de resumen
  - `process_incident_creation()`: Función principal para análisis al crear incidente
  
- ✅ `app/services/assignment_service.py`: Asignación inteligente de talleres
  - `find_best_workshop()`: Algoritmo de scoring (distancia + disponibilidad + prioridad)
  - `assign_technician()`: Asignación automática de técnico
  - `get_workshops_in_range()`: Talleres cercanos

### 3. Backups
- ✅ `app/models.py.backup`: Respaldo de modelos originales
- ✅ `app/schemas.py.backup`: Respaldo de schemas originales

---

## 🚧 PENDIENTE DE IMPLEMENTAR

### 4. Backend - Schemas (Pydantic)

**Archivo**: `/backend/app/schemas.py`

Debe incluir schemas para:
- Workshop (WorkshopCreate, WorkshopUpdate, WorkshopResponse)
- Technician (TechnicianCreate, TechnicianUpdate, TechnicianResponse)
- Payment (PaymentCreate, PaymentUpdate, PaymentResponse)
- IncidentHistory (IncidentHistoryResponse)
- Incident actualizado con nuevos campos
- Schemas especiales:
  - `IncidentAssignmentRequest`
  - `IncidentAcceptRequest`
  - `LocationUpdate`
  - `WorkshopStats`

**Status**: Backup creado, falta reescribir el archivo

---

### 5. Backend - Routers/Endpoints

#### A. Workshop Router
**Archivo**: `/backend/app/routers/workshops.py`

**Endpoints necesarios**:
```
POST   /workshops                    # Crear taller (WORKSHOP role)
GET    /workshops                    # Listar talleres
GET    /workshops/me                 # Info del taller autenticado
GET    /workshops/{id}               # Detalle de taller
PATCH  /workshops/{id}               # Actualizar taller
DELETE /workshops/{id}               # Eliminar taller

# Gestión de técnicos
POST   /workshops/{id}/technicians   # Agregar técnico
GET    /workshops/{id}/technicians   # Listar técnicos
PATCH  /workshops/{id}/technicians/{tech_id}  # Actualizar técnico
DELETE /workshops/{id}/technicians/{tech_id}  # Eliminar técnico

# Incidentes disponibles
GET    /workshops/incidents/available  # Incidentes sin asignar (RBAC: solo taller autenticado)
POST   /workshops/incidents/{id}/accept # Aceptar incidente
POST   /workshops/incidents/{id}/reject # Rechazar incidente

# Estadísticas
GET    /workshops/stats              # Estadísticas del taller autenticado
GET    /workshops/history            # Historial del taller (RBAC)
```

#### B. Technician Router
**Archivo**: `/backend/app/routers/technicians.py`

**Endpoints necesarios**:
```
GET    /technicians/me/incidents     # Incidentes asignados al técnico
PATCH  /technicians/me/location      # Actualizar ubicación del técnico
PATCH  /technicians/me/availability  # Cambiar disponibilidad
```

#### C. Payment Router
**Archivo**: `/backend/app/routers/payments.py`

**Endpoints necesarios**:
```
POST   /payments                     # Crear registro de pago
GET    /payments/{id}                # Obtener pago
PATCH  /payments/{id}                # Actualizar pago (marcar como pagado)
GET    /payments/incident/{incident_id}  # Pago de un incidente

# Admin endpoints
GET    /admin/payments               # Todos los pagos (ADMIN only)
GET    /admin/payments/stats         # Estadísticas de comisiones
```

#### D. Admin Router  
**Archivo**: `/backend/app/routers/admin.py`

**Endpoints necesarios**:
```
GET    /admin/workshops              # Todos los talleres
GET    /admin/incidents              # Todos los incidentes
GET    /admin/history                # Historial completo del sistema
GET    /admin/stats                  # Estadísticas generales
PATCH  /admin/workshops/{id}/activate    # Activar/desactivar taller
```

#### E. Actualizar Incidents Router  
**Archivo**: `/backend/app/routers/incidents.py`

**Modificaciones necesarias**:
```
# Actualizar POST /incidents para incluir procesamiento de IA
- Llamar a ai_service.process_incident_creation()
- Guardar classification, priority, ai_summary

# Actualizar PATCH /incidents/{id}
- Al cambiar a "accepted": guardar accepted_at
- Al cambiar a "in_progress": guardar started_at
- Al cambiar a "completed": guardar completed_at
- Registrar en IncidentHistory cada cambio de estado
- RBAC: Solo el taller asignado puede cambiar estado

# Nuevo endpoint
GET /incidents/{id}/history  # Obtener historial de cambios
```

---

### 6. Backend - Middleware y Dependencias

#### A. Actualizar Auth/Dependencies
**Archivo**: `/backend/app/auth.py`

**Agregar funciones de autorización**:
```python
# Role-based access control decorators
async def require_role(required_roles: List[UserRole]):
    # Verificar que el usuario tiene uno de los roles requeridos
    pass

async def get_current_workshop(current_user: User, db: Session):
    # Obtener taller del usuario autenticado
    pass

async def verify_workshop_owner(workshop_id: int, current_user: User, db: Session):
    # Verificar que el usuario es dueño del taller
    pass
```

#### B. Crear Utility Functions
**Archivo**: `/backend/app/utils.py`

```python
from decimal import Decimal

def calculate_payment(amount: float, commission_percentage: float = 10.0):
    """Calcular comisión y ganancia del taller"""
    total = Decimal(str(amount))
    commission = total * Decimal(str(commission_percentage / 100))
    workshop_earnings = total - commission
    
    return {
        "total": float(total),
        "commission": float(commission),
        "workshop_earnings": float(workshop_earnings)
    }
```

---

### 7. Backend - Main Configuration

#### A. Actualizar main.py
**Archivo**: `/backend/main.py`

**Agregar imports de nuevos routers**:
```python
from app.routers import auth, users, vehicles, incidents, workshops, technicians, payments, admin

# Include routers
app.include_router(workshops.router)
app.include_router(technicians.router)
app.include_router(payments.router)
app.include_router(admin.router)
```

#### B. Actualizar variables de entorno  
**Archivo**: `/backend/.env`

**Agregar**:
```
MAPBOX_API_KEY=pk.eyJ1IjoiYW5nZWxtb3JhMzciLCJhIjoiY21uczVzemtqMGEwbTJzcTA5NGJuODk4eSJ9.N1m0wsLi4oNu-dmRDG4z1w
AI_ENABLED=false
MAX_WORKSHOP_DISTANCE_KM=50
```

#### C. Actualizar requirements.txt
**Archivo**: `/backend/requirements.txt`

**Agregar**:
```
httpx==0.25.2       # Para llamadas a Mapbox API
```

---

### 8. Docker

#### A. Actualizar docker-compose.yml

**Agregar variables de entorno al servicio backend**:
```yaml
backend:
  # ... existing config
  environment:
    # ... existing vars
    MAPBOX_API_KEY: ${MAPBOX_API_KEY:-your_mapbox_key}
    AI_ENABLED: "false"
    MAX_WORKSHOP_DISTANCE_KM: "50"
```

#### B. Crear .env en raíz
**Archivo**: `/.env`

```
MAPBOX_API_KEY=pk.eyJ1IjoiYW5nZWxtb3JhMzciLCJhIjoiY21uczVzemtqMGEwbTJzcTA5NGJuODk4eSJ9.N1m0wsLi4oNu-dmRDG4z1w
AI_ENABLED=false
```

---

### 9. Frontend Web (Angular)

#### A. Instalar Mapbox GL JS
```bash
cd frontend
npm install mapbox-gl @types/mapbox-gl
```

#### B. Actualizar environment.ts
**Archivo**: `/frontend/src/environments/environment.ts`

```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8000',
  mapboxToken: 'pk.eyJ1IjoiYW5nZWxtb3JhMzciLCJhIjoiY21uczVzemtqMGEwbTJzcTA5NGJuODk4eSJ9.N1m0wsLi4oNu-dmRDG4z1w'
};
```

#### C. Crear servicios Angular

**1. Workshop Service**  
**Archivo**: `/frontend/src/app/services/workshop.service.ts`

```typescript
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class WorkshopService {
  private apiUrl = `${environment.apiUrl}/workshops`;

  constructor(private http: HttpClient) {}

  getAvailableIncidents(): Observable<any> {
    return this.http.get(`${this.apiUrl}/incidents/available`);
  }

  acceptIncident(incidentId: number, data: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/incidents/${incidentId}/accept`, data);
  }

  getStats(): Observable<any> {
    return this.http.get(`${this.apiUrl}/stats`);
  }

  getHistory(): Observable<any> {
    return this.http.get(`${this.apiUrl}/history`);
  }
}
```

**2. Mapbox Service**  
**Archivo**: `/frontend/src/app/services/mapbox.service.ts`

```typescript
import { Injectable } from '@angular/core';
import * as mapboxgl from 'mapbox-gl';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class MapboxService {
  constructor() {
    (mapboxgl as any).accessToken = environment.mapboxToken;
  }

  createMarshallMap(container: string, center: [number, number], zoom: number = 12): mapboxgl.Map {
    return new mapboxgl.Map({
      container,
      style: 'mapbox://styles/mapbox/streets-v12',
      center,
      zoom
    });
  }

  addMarker(map: mapboxgl.Map, lngLat: [number, number], color: string = '#3b82f6'): mapboxgl.Marker {
    return new mapboxgl.Marker({ color })
      .setLngLat(lngLat)
      .addTo(map);
  }

  async getRoute(origin: [number, number], destination: [number, number]): Promise<any> {
    const url = `https://api.mapbox.com/directions/v5/mapbox/driving/${origin[0]},${origin[1]};${destination[0]},${destination[1]}?geometries=geojson&access_token=${environment.mapboxToken}`;
    
    const response = await fetch(url);
    return response.json();
  }
}
```

#### D. Componentes Angular a crear/actualizar

**1. Workshop Dashboard**  
**Archivo**: `/frontend/src/app/components/workshop-dashboard/`

- Mostrar incidentes disponibles en lista
- Mapa con marcadores de incidentes
- Botón "Aceptar" para cada incidente
- Filtros por distancia/prioridad

**2. Incident Detail with Map**  
**Archivo**: `/frontend/src/app/components/incident-detail-map/`

- Mapa mostrando ubicación del incidente
- Información completa del incidente
- Ruta desde taller hasta incidente
- Estimación de tiempo de llegada

**3. Workshop Stats**  
**Archivo**: `/frontend/src/app/components/workshop-stats/`

- KPIs actualizadas con datos reales
- Gráficos de ingresos y comisiones
- Historial de incidentes atendidos

---

### 10. Frontend Mobile (Flutter)

#### A. Agregar dependencias
**Archivo**: `/movile_front/pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  # existing dependencies...
  mapbox_gl: ^0.16.0           # Mapbox Maps SDK
  geolocator: ^10.1.0           # Ubicación GPS
  image_picker: ^1.0.4          # Seleccionar imágenes
  record: ^5.0.0                # Grabar audio
  dio: ^5.3.3                   # HTTP client mejorado
```

#### B. Crear servicio de Mapbox
**Archivo**: `/movile_front/lib/services/mapbox_service.dart`

```dart
import 'package:mapbox_gl/mapbox_gl.dart';

class MapboxService {
  static const String accessToken = 'pk.eyJ1IjoiYW5nZWxtb3JhMzciLCJhIjoiY21uczVzemtqMGEwbTJzcTA5NGJuODk4eSJ9.N1m0wsLi4oNu-dmRDG4z1w';
  
  static MapboxMap? mapController;
  
  static Future<LatLng> getCurrentLocation() async {
    // Use Geolocator to get GPS position
    // Return LatLng
  }
  
  static Future<String> reverseGeocode(LatLng position) async {
    // Call Mapbox Geocoding API
    // Return address string
  }
}
```

#### C. Nueva pantalla: Emergency Create with Map
**Archivo**: `/movile_front/lib/screens/emergency_create_screen.dart`

**Funcionalidades**:
- Mapa interactivo para seleccionar ubicación
- Botón "Usar mi ubicación actual"
- Campo descripción del problema
- Botón para tomar/seleccionar foto
- Botón para grabar audio
- Mostrar resumen de IA antes de enviar
- Botón "Solicitar ayuda" que envía todo al backend

**Flujo**:
1. Usuario selecciona vehículo
2. Usuario selecciona ubicación en mapa (o usa GPS)
3. Usuario describe el problema (texto)
4. Usuario opcionalmente agrega foto
5. Usuario opcionalmente graba audio
6. Al enviar, el backend procesa con IA
7. Se muestra confirmación con clasificación y prioridad

---

### 11. Migración de Base de Datos

**IMPORTANTE**: Los modelos han cambiado significativamente. Opciones:

#### Opción A: Recrear base de datos (desarrollo)
```bash
docker-compose down -v
docker-compose up --build
```

#### Opción B: Usar Alembic (producción)
```bash
cd backend
alembic revision --autogenerate -m "Add CICLO 2 models"
alembic upgrade head
```

---

## 📝 ORDEN DE IMPLEMENTACIÓN RECOMENDADO

### Fase 1: Backend Core (PRIORITARIO)
1. ✅ Modelos actualizados
2. ✅ Servicios (Mapbox, AI, Assignment)
3. 🔲 Actualizar schemas.py
4. 🔲 Crear workshops router
5. 🔲 Crear payments router
6. 🔲 Crear admin router
7. 🔲 Actualizar incidents router con IA
8. 🔲 Actualizar main.py
9. 🔲 Actualizar .env y Docker

### Fase 2: Testing Backend
10. 🔲 Recrear base de datos
11. 🔲 Probar creación de talleres
12. 🔲 Probar asignación de incidentes
13. 🔲 Probar sistema de pagos

### Fase 3: Frontend Web
14. 🔲 Instalar Mapbox GL JS
15. 🔲 Crear servicios Angular (workshop, mapbox)
16. 🔲 Actualizar dashboard con mapa
17. 🔲 Crear componente incident-detail-map
18. 🔲 Implementar aceptación de incidentes

### Fase 4: Frontend Mobile
19. 🔲 Instalar dependencias (Mapbox, Geolocator, etc.)
20. 🔲 Crear servicio Mapbox Flutter
21. 🔲 Actualizar pantalla crear emergencia con mapa
22. 🔲 Implementar captura de imagen/audio
23. 🔲 Mostrar análisis de IA

### Fase 5: Integración y Pruebas
24. 🔲 Flujo completo end-to-end
25. 🔲 Testing de asignación inteligente
26. 🔲 Testing de pagos
27. 🔲 Documentación final

---

## 🔑 API KEYS

- **Mapbox**: `pk.eyJ1IjoiYW5nZWxtb3JhMzciLCJhIjoiY21uczVzemtqMGEwbTJzcTA5NGJuODk4eSJ9.N1m0wsLi4oNu-dmRDG4z1w`
- **Ubicación**: Ya agregada a los servicios, needs agregar a .env

---

## 🚨 NOTAS IMPORTANTES

1. **Migraciones**: Los modelos cambiaron mucho. Recomiendo recrear la BD en desarrollo.

2. **RBAC Estricto**: 
   - Taller SOLO ve sus propios incidentes
   - Admin ve TODO
   - Cliente ve solo sus solicitudes

3. **Mapbox Quotas**: 
   - Free tier: 100,000 requests/month
   - Optimizar llamadas (cachear resultados cuando sea posible)

4. **IA Service**:
   - Actualmente usa lógica simple de keywords
   - Preparado para integración futura con OpenAI/Google Cloud

5. **Sistema de Pagos**:
   - NO usar pasarelas (Stripe, PayPal, etc.)
   - Registro manual de pagos en efectivo/transferencia
   - Cálculo automático de comisiones 10%

---

## 📚 RECURSOS

- **Mapbox Docs**: https://docs.mapbox.com/
- **Mapbox GL JS**: https://docs.mapbox.com/mapbox-gl-js/
- **Mapbox Flutter**: https://pub.dev/packages/mapbox_gl
- **FastAPI**: https://fastapi.tiangolo.com/
- **Angular**: https://angular.io/
- **Flutter**: https://flutter.dev/

---

## ✉️ SIGUIENTE PASO INMEDIATO

**Continuar con Task #4**: Crear el archivo de schemas.py actualizado y luego proceder con los routers.

**Comando para verificar progreso**:
```bash
# Ver archivos creados
ls -la backend/app/services/
ls -la backend/app/models.py

# Verificar backup
ls -la backend/app/*.backup
```
