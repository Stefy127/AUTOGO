# 🚗 AutoGo - Plataforma de Emergencias Vehiculares

Sistema completo fullstack para gestión de emergencias vehiculares con backend FastAPI, frontend Angular, app móvil Flutter, integración con Mapbox y estructura base para IA.

---

## 📋 ESTADO DEL PROYECTO

### ✅ CICLO 1 - COMPLETADO
- Backend FastAPI con autenticación JWT
- Frontend Angular con dashboard
- App móvil Flutter
- Base de datos PostgreSQL
- Docker compose funcional
- CRUD completo de usuarios, vehículos e incidentes

### 🚧 CICLO 2 - EN PROGRESO (40%)
- ✅ **Modelos extendidos**: Workshop, Technician, Payment, IncidentHistory
- ✅ **Servicios implementados**: Mapbox API, IA (estructura base), Asignación inteligente
- ✅ **Configuración**: API keys, environment variables
- 🔲 **Routers pendientes**: Workshops, Payments, Admin
- 🔲 **Frontend pendiente**: Integración con Mapbox (Angular + Flutter)

---

## 📁 Estructura del Proyecto

```
AutoGo/
├── backend/                     # FastAPI + PostgreSQL
│   ├── app/
│   │   ├── models.py           # ✅ ACTUALIZADO CICLO 2
│   │   ├── schemas.py          # 🚧 Pendiente actualizar
│   │   ├── services/           # ✅ NUEVO CICLO 2
│   │   │   ├── mapbox_service.py     # Integración Mapbox
│   │   │   ├── ai_service.py         # Estructura IA
│   │   │   └── assignment_service.py # Asignación inteligente
│   │   └── routers/
│   │       ├── auth.py
│   │       ├── users.py
│   │       ├── vehicles.py
│   │       ├── incidents.py
│   │       ├── workshops.py    # 🚧 Pendiente crear
│   │       ├── payments.py     # 🚧 Pendiente crear
│   │       └── admin.py        # 🚧 Pendiente crear
├── frontend/                    # Angular (Panel Web para Talleres)
├── movile_front/                # Flutter (App Móvil para Clientes)
├── docker-compose.yml
├── CICLO2_IMPLEMENTATION_GUIDE.md   # 📖 Guía completa CICLO 2
├── CICLO2_SUMMARY.md                # 📊 Resumen ejecutivo
├── CICLO2_CHECKLIST.md              # ✅ Checklist de tareas
├── QUICK_REFERENCE.md               # ⚡ Referencia rápida
└── setup_ciclo2.sh                  # 🔧 Script de configuración

```

---

## 🚀 Ejecución Rápida

### 1. Con Docker (Recomendado)

```bash
cd /home/angel/Escritorio/AutoGo
docker-compose up --build
```

**Servicios disponibles**:
- **Backend API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **Frontend Web**: http://localhost
- **PostgreSQL**: localhost:5433

### 2. Configuración CICLO 2

```bash
# Ejecutar script de configuración automática
./setup_ciclo2.sh

# Recrear base de datos con nuevos modelos
docker-compose down -v
docker-compose up --build
```

---

## 📱 Aplicación Móvil (Flutter)

```bash
cd movile_front
flutter pub get

# Configurar URL del backend en lib/services/api_service.dart
# baseUrl = 'http://192.168.110.17:8000'  # Tu IP local

flutter run
```

---

## 🆕 NOVEDADES CICLO 2

### Backend

#### 🗄️ Nuevos Modelos
- **Workshop**: Talleres con geolocalización (Mapbox)
- **Technician**: Técnicos con disponibilidad en tiempo real
- **Payment**: Sistema de pagos sin pasarela, comisiones automáticas (10%)
- **IncidentHistory**: Trazabilidad completa de cambios de estado

#### 🔧 Nuevos Servicios
- **MapboxService**: Geocoding, rutas, distancias
- **AIService**: Clasificación automática de incidentes
- **AssignmentService**: Asignación inteligente de talleres por scoring

#### 🎯 Funcionalidades Clave
- **Asignación Inteligente**: Algoritmo que considera distancia (50%), disponibilidad (30%) y prioridad (20%)
- **Procesamiento de IA**: Análisis automático al crear incidente (clasificación, prioridad, resumen)
- **Geolocalización**: Integración completa con Mapbox API
- **RBAC Estricto**: Taller solo ve sus incidentes, Admin ve todo

### Arquitectura

```
Cliente crea incidente
    ↓
IA analiza (clasificación, prioridad)
    ↓
Mapbox calcula distancias a talleres
    ↓
Assignment Service asigna mejor taller
    ↓
Taller acepta y asigna técnico
    ↓
Servicio se completa
    ↓
Pago se registra (comisión 10%)
```

---

## 🔐 Roles y Permisos

| Rol | Permisos |
|-----|----------|
| **CLIENT** | Ver solo sus incidentes y vehículos |
| **WORKSHOP** | Ver solo incidentes asignados a su taller, gestionar técnicos |
| **TECHNICIAN** | Ver solo incidentes asignados a él |
| **ADMIN** | Ver TODO, gestionar talleres, estadísticas globales |

---

## 📊 Funcionalidades por Rol

### Cliente (App Móvil)
- Registrar vehículos
- Crear emergencias con ubicación (Mapbox)
- Adjuntar fotos y audio
- Ver análisis de IA
- Seguimiento en tiempo real
- Historial de emergencias

### Taller (Panel Web)
- Ver incidentes disponibles en mapa
- Aceptar/rechazar incidentes
- Ver ruta hacia cliente
- Asignar técnicos
- Registrar pagos
- Ver estadísticas y comisiones
- Historial de servicios

### Admin (Panel Web)
- Dashboard global
- Gestionar talleres
- Ver todos los incidentes
- Estadísticas completas
- Gestión de pagos y comisiones

---

## 🔑 Variables de Entorno

### Backend (.env)
```env
DATABASE_URL=postgresql://autogo:autogo123@postgres:5432/autogo_db
SECRET_KEY=09d25e094faa6ca2556c818166b7a9563b93f7099f6f0f4caa6cf63b88e8d3e7
MAPBOX_API_KEY=pk.eyJ1IjoiYW5nZWxtb3JhMzciLCJhIjoiY21uczVzemtqMGEwbTJzcTA5NGJuODk4eSJ9.N1m0wsLi4oNu-dmRDG4z1w
AI_ENABLED=false
MAX_WORKSHOP_DISTANCE_KM=50
```

---

## 📝 Endpoints Principales

### CICLO 1 (Existentes)
```
POST   /auth/register
POST   /auth/login/json
GET    /users/profile
POST   /vehicles
GET    /vehicles
POST   /incidents
GET    /incidents
PATCH  /incidents/{id}
```

### CICLO 2 (Nuevos - Pendientes)
```
# Talleres
POST   /workshops
GET    /workshops/incidents/available
POST   /workshops/incidents/{id}/accept
GET    /workshops/stats
GET    /workshops/history

# Pagos
POST   /payments
GET    /payments/{id}
PATCH  /payments/{id}

# Admin
GET    /admin/workshops
GET    /admin/incidents
GET    /admin/history
GET    /admin/stats
```

---

##óm 🛠️ Tecnologías

### Backend
- FastAPI 0.109
- SQLAlchemy 2.0
- PostgreSQL 15
- JWT Authentication
- Httpx (Mapbox API)
- Pydantic 2.5

### Frontend Web
- Angular 17
- TypeScript 5.2
- Mapbox GL JS (pendiente)
- RxJS 7.8

### Frontend Mobile
- Flutter 3.0+
- Dart
- Provider 6.1
- Mapbox Flutter SDK (pendiente)
- Geolocator

### Infrastructure
- Docker & Docker Compose
- Nginx
- PostgreSQL 15

---

## 📚 Documentación del CICLO 2

| Documento | Descripción |
|-----------|-------------|
| [CICLO2_IMPLEMENTATION_GUIDE.md](CICLO2_IMPLEMENTATION_GUIDE.md) | 📖 Guía completa paso a paso con ejemplos de código |
| [CICLO2_SUMMARY.md](CICLO2_SUMMARY.md) | 📊 Resumen ejecutivo de lo implementado |
| [CICLO2_CHECKLIST.md](CICLO2_CHECKLIST.md) | ✅ Checklist de tareas completadas y pendientes |
| [QUICK_REFERENCE.md](QUICK_REFERENCE.md) | ⚡ Referencia rápida de comandos y APIs |

---

## 🧪 Testing

### Probar Servicios de Mapbox
```python
# En Python shell dentro del contenedor
docker exec -it autogo_backend python

from app.services.mapbox_service import mapbox_service
import asyncio

# Test geocoding
coords = asyncio.run(mapbox_service.geocode_address("Reforma 222, CDMX"))
print(coords)  # (19.4270, -99.1687)

# Test distancia
result = asyncio.run(mapbox_service.get_distance_and_duration(
    19.4326, -99.1332, 19.4270, -99.1687
))
print(result)
```

### Probar API
```bash
# Ver documentación interactiva
open http://localhost:8000/docs

# Crear taller (cuando se implemente el endpoint)
curl -X POST http://localhost:8000/workshops \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Taller AutoFix",
    "address": "Reforma 222, CDMX",
    "latitude": 19.4270,
    "longitude": -99.1687
  }'
```

---

## 🐛 Solución de Problemas

### Error: Mapbox API no responde
```bash
# Verificar API key en .env
cat backend/.env | grep MAPBOX

# Ver logs de backend
docker-compose logs -f backend
```

### Error: No se crean nuevas tablas
```bash
# Recrear base de datos completamente
docker-compose down -v
docker-compose up --build
```

### Error: Flutter no se conecta
```bash
# Verificar IP local
hostname -I

# Actualizar en Flutter
# lib/services/api_service.dart
# baseUrl = 'http://YOUR_IP:8000'
```

---

## 🚦 Estado de Implementación

### ✅ Completado
- [x] Modelos de base de datos extendidos
- [x] Servicios de Mapbox, IA y Asignación
- [x] Configuración de environment variables
- [x] Documentación completa
- [x] Scripts de setup automatizados

### 🔄 En Progreso
- [ ] Schemas de Pydantic actualizados
- [ ] Routers de talleres y pagos
- [ ] Integración frontend con Mapbox
- [ ] Testing end-to-end

### 📅 Roadmap
- [ ] WebSockets para notificaciones en tiempo real
- [ ] Integración real de IA (OpenAI/Google Cloud)
- [ ] Sistema de rating de talleres
- [ ] Chat en vivo taller-cliente
- [ ] Upload de imágenes a S3/Cloud Storage

---

## 👨‍💻 Desarrollo

### Setup Inicial CICLO 2
```bash
# 1. Ejecutar script de configuración
./setup_ciclo2.sh

# 2. Verificar archivos creados
ls -la backend/app/services/
ls -la backend/app/models.py

# 3. Leer guía de implementación
cat CICLO2_IMPLEMENTATION_GUIDE.md

# 4. Continuar con siguiente paso según CICLO2_CHECKLIST.md
```

### Contribuir
1. Revisar `CICLO2_CHECKLIST.md` para tareas pendientes
2. Leer `CICLO2_IMPLEMENTATION_GUIDE.md` sección correspondiente
3. Implementar según ejemplos de código proporcionados
4. Probar con Docker local
5. Documentar cambios

---

## 📄 Licencia

Proyecto educativo - AutoGo 2026

---

## 📞 Soporte

- **Documentación**: Ver carpeta raíz (`CICLO2_*.md`)
- **API Docs**: http://localhost:8000/docs
- **Logs**: `docker-compose logs -f`

---

**Versión**: CICLO 2 (40% completado)  
**Última actualización**: 9 de abril de 2026  
**Próximo milestone**: Completar routers de talleres y pagos
