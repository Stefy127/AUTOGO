# 🚗 AutoGo - Plataforma de Emergencias Vehiculares

Sistema completo fullstack para gestión de emergencias vehiculares con backend FastAPI, frontend Angular y app móvil Flutter.

## 📁 Estructura del Proyecto

```
AutoGo/
├── backend/          # FastAPI + PostgreSQL
├── frontend/         # Angular (Panel Web para Talleres)
├── movile_front/     # Flutter (App Móvil para Clientes)
└── docker-compose.yml
```

## 🚀 Ejecución Rápida con Docker

### Requisitos
- Docker
- Docker Compose

### Pasos

1. **Clonar o ubicarse en el directorio del proyecto**
```bash
cd Escritorio/AutoGo
```

2. **Construir y ejecutar todos los servicios**
```bash
docker-compose up --build
```

3. **Acceder a los servicios**
- **Backend API**: http://localhost:8000
- **Frontend Web**: http://localhost
- **API Docs**: http://localhost:8000/docs

### Detener servicios
```bash
docker-compose down
```

### Ver logs
```bash
docker-compose logs -f
```

---

## 📱 Aplicación Móvil (Flutter)

La app móvil **no se ejecuta en Docker**, se ejecuta localmente:

### Requisitos
- Flutter SDK (>= 3.0.0)
- Android Studio / Xcode
- Emulador o dispositivo físico

### Instalación

```bash
cd movile_front
flutter pub get
```

### Configurar URL del Backend

Edita `movile_front/lib/services/api_service.dart`:

```dart
// Para Android Emulator
static const String baseUrl = 'http://10.0.2.2:8000';

// Para iOS Simulator
static const String baseUrl = 'http://localhost:8000';

// Para dispositivo físico (reemplaza con tu IP local)
static const String baseUrl = 'http://192.168.1.XXX:8000';
```

### Ejecutar

```bash
flutter run
```

---

## 🔧 Desarrollo Local (Sin Docker)

### Backend

```bash
cd backend
python -m venv venv
source venv/bin/activate  # En Linux/Mac
# venv\Scripts\activate   # En Windows
pip install -r requirements.txt
uvicorn main:app --reload
```

### Frontend Web

```bash
cd frontend
npm install
ng serve
```

Accede en: http://localhost:4200

---

## 📊 Funcionalidades Implementadas

### ✅ CICLO 1 (MVP)

#### Backend (FastAPI)
- ✅ Autenticación JWT con roles (CLIENT, WORKSHOP, ADMIN)
- ✅ CRUD de usuarios
- ✅ CRUD de vehículos
- ✅ CRUD de incidentes/emergencias
- ✅ Base de datos PostgreSQL
- ✅ Documentación automática (Swagger)

#### Frontend Web (Angular)
- ✅ Login con redirección por rol
- ✅ Dashboard con estadísticas para admin
- ✅ Lista de incidentes en tiempo real
- ✅ Filtrado por estado
- ✅ Actualización de estado de incidentes
- ✅ Diseño responsive y moderno

#### App Móvil (Flutter)
- ✅ Registro e inicio de sesión
- ✅ Registro de vehículos
- ✅ Creación de emergencias
- ✅ Lista de emergencias del usuario
- ✅ Detalles de emergencias
- ✅ Diseño minimalista tipo Uber

---

### ✅ CICLO 2 (Gestión de Talleres y IA)

#### Backend (FastAPI 2.0.0) - 34 Endpoints
- ✅ **Sistema de Talleres**: Registro, perfil, activación/desactivación
- ✅ **Gestión de Mecánicos**: CRUD de técnicos por taller
- ✅ **Sistema de Pagos**: Auto-cálculo de comisiones (10% default)
- ✅ **Historial de Incidentes**: Auditoría completa de cambios
- ✅ **Asignación Inteligente**: Algoritmo de scoring (distancia, disponibilidad, prioridad)
- ✅ **Integración Mapbox**: Geocoding, rutas, distancias
- ✅ **Sistema de Prioridades**: Bajo, Medio, Alto
- ✅ **5 Estados de Incidente**: pending, accepted, in_progress, completed, cancelled
- ✅ **Clasificación IA**: Estructura preparada para OpenAI/Google Cloud
- ✅ **Panel de Admin**: Estadísticas globales, gestión de talleres, reportes de comisiones

#### Frontend Web Angular - Panel de Talleres
- ✅ **Workshop Dashboard Rediseñado (Sidebar Layout)**:
  - ✅ **Navegación sidebar fija** con 5 vistas independientes
  - ✅ **Vista Dashboard Principal**:
    - ✅ Card informativa del taller (6 campos: nombre, dirección, teléfono, estado, comisión, mecánicos)
    - ✅ 4 tarjetas estadísticas (total atendidas, en progreso, completadas, 💰 ganancias totales)
    - ✅ **Barras de progreso por mecánico** mostrando rendimiento con % de participación
    - ✅ Tabla de emergencias recientes (últimas 5 con detalles completos)
  - ✅ **Vista Editar Información**: Formulario completo del taller con GPS opcional
  - ✅ **Vista Agregar Mecánico**: Formulario + lista de mecánicos registrados con estados
  - ✅ **Vista Emergencias Disponibles**: Cards con análisis IA y botones aceptar/rechazar
  - ✅ **Vista Historial**: Tabla completa de emergencias completadas/canceladas con ganancias
  
- ✅ **Registro de Talleres Mejorado**:
  - ✅ Formulario con 6 campos: nombre del taller, propietario, email, teléfono, dirección, contraseña
  - ✅ **Campos GPS opcionales** (latitud, longitud) para ubicación exacta
  - ✅ Creación automática de perfil de taller al registrarse
  - ✅ Redirección a dashboard después del login
  
- ✅ **Analytics y Métricas**:
  - ✅ Cálculo de ganancias totales (suma de workshop_earnings)
  - ✅ Estadísticas por mecánico (incidentes completados, porcentaje de participación)
  - ✅ Contador de emergencias disponibles con badge en sidebar
  - ✅ Timeline completa de seguimiento de incidentes
  
- ✅ **Visualización Mejorada**:
  - ✅ Badges coloridos de prioridad (🔴 Alta, 🟡 Media, 🟢 Baja)
  - ✅ Badges de estado (pending, accepted, in_progress, completed, cancelled)
  - ✅ Resumen de análisis IA con icono 🤖 en cards de incidentes
  - ✅ Información de pago y comisiones en historial
  - ✅ Diseño responsive con sidebar colapsable en móviles
  
- ✅ **Servicios HTTP**:
  - ✅ WorkshopService: gestión completa de talleres y mecánicos
  - ✅ PaymentService: tracking de pagos y comisiones
  - ✅ AdminService: panel administrativo completo
  - ✅ MapboxService: integración de mapas

#### App Móvil Flutter - Mejoras CICLO 2
- ✅ **Modelos Actualizados**: Workshop, Technician, Payment, IncidentHistory
- ✅ **Incident Extendido**: 15+ campos nuevos (priority, classification, ai_summary, workshop_id, technician_id, timestamps)
- ✅ **Lista de Emergencias Mejorada**:
  - ✅ Dual badges (estado + prioridad)
  - ✅ Resumen IA en cards
  - ✅ Información de taller asignado
  - ✅ Modal de detalles completo con timeline
  - ✅ Información de pago integrada
  
- ✅ **Formulario de Emergencia**:
  - ✅ Selector de prioridad (3 niveles)
  - ✅ Envío de prioridad al crear incidente
  
- ✅ **Servicios**:
  - ✅ MapboxService: geocoding, distancias, mapas estáticos

---

## 🔐 Usuarios de Prueba

Para probar el sistema, debes primero registrar un usuario usando:
- La app móvil (opción "Regístrate")
- El endpoint `/auth/register` del backend
- Postman/Thunder Client

O puedes insertar manualmente en la base de datos:

```sql
-- Conectarse a PostgreSQL (dentro del contenedor)
docker exec -it autogo_postgres psql -U autogo -d autogo_db
```

---

## 📝 Endpoints del API

### Autenticación
- `POST /auth/register` - Registrar usuario (client, workshop, admin)
- `POST /auth/login` - Login con form-data
- `POST /auth/login/json` - Login con JSON

### Usuarios
- `GET /users/profile` - Perfil del usuario actual
- `GET /users/me` - Información del usuario

### Vehículos
- `POST /vehicles` - Crear vehículo
- `GET /vehicles` - Listar vehículos del usuario
- `GET /vehicles/{id}` - Obtener vehículo por ID
- `DELETE /vehicles/{id}` - Eliminar vehículo

### Incidentes
- `POST /incidents` - Crear incidente (con prioridad)
- `GET /incidents` - Listar incidentes (filtrado por rol)
- `GET /incidents/{id}` - Obtener incidente por ID
- `PATCH /incidents/{id}` - Actualizar incidente
- `DELETE /incidents/{id}` - Eliminar incidente
- `GET /incidents/{id}/history` - Historial del incidente
- `POST /incidents/{id}/cancel` - Cancelar incidente

### 🆕 Talleres (CICLO 2) - 9 Endpoints
- `POST /workshops` - Crear taller (requiere rol WORKSHOP)
- `GET /workshops/me` - Obtener mi taller
- `PATCH /workshops/me` - Actualizar mi taller
- `POST /workshops/me/technicians` - Agregar mecánico a mi taller
- `GET /workshops/me/technicians` - Listar mecánicos de mi taller
- `GET /workshops/incidents/available` - Ver incidentes disponibles en el área
- `POST /workshops/incidents/{id}/accept` - Aceptar incidente (con asignación de mecánico)
- `POST /workshops/incidents/{id}/reject` - Rechazar incidente
- `GET /workshops/me/stats` - Estadísticas del taller

### 🆕 Pagos (CICLO 2) - 5 Endpoints
- `POST /payments` - Crear pago (solo COMPLETED incidents)
- `GET /payments/{id}` - Obtener pago por ID
- `PATCH /payments/{id}` - Actualizar pago (marcar como pagado)
- `GET /payments/incident/{id}` - Obtener pago de un incidente
- `GET /payments` - Listar pagos (filtrado por rol)

### 🆕 Administración (CICLO 2) - 11 Endpoints
- `GET /admin/workshops` - Listar todos los talleres
- `PATCH /admin/workshops/{id}/activate` - Activar/desactivar taller
- `GET /admin/incidents` - Listar todos los incidentes (con filtros)
- `DELETE /admin/incidents/{id}` - Eliminar incidente
- `GET /admin/history` - Historial completo de todos los incidentes
- `GET /admin/payments` - Listar todos los pagos
- `GET /admin/payments/commissions` - Reporte de comisiones (con rango de fechas)
- `GET /admin/stats` - Estadísticas globales de la plataforma
- `GET /admin/users` - Listar todos los usuarios
- `DELETE /admin/users/{id}` - Eliminar usuario

**Total:** 34 endpoints operativos

---

## 🎨 Tecnologías Utilizadas

- **Backend**: FastAPI, SQLAlchemy, PostgreSQL, JWT, Pydantic
- **Frontend Web**: Angular 17, TypeScript, CSS3
- **App Móvil**: Flutter, Dart, Provider
- **Contenedores**: Docker, Docker Compose
- **Base de Datos**: PostgreSQL 15

---

### Resetear base de datos

```bash
docker-compose down -v
docker-compose up --build
```

---

### 🚀 Características Destacadas

1. **Sistema Multi-Rol**
   - 👤 CLIENT: App móvil para reportar emergencias
   - 🔧 WORKSHOP: Panel web para gestionar taller y mecánicos
   - 👨‍💼 ADMIN: Dashboard con estadísticas y control total

2. **Gestión de Talleres**
   - Perfil completo del taller (ubicación en mapa)
   - Registro y gestión de mecánicos
   - Aceptación/rechazo de emergencias
   - Asignación automática por proximidad
   - Tracking de comisiones (10% default)

3. **Sistema Inteligente**
   - Asignación por scoring (distancia 50%, disponibilidad 30%, prioridad 20%)
   - Priorización de emergencias (baja, media, alta)
   - Clasificación preparada para IA
   - Historial completo de auditoría

4. **Integración Mapbox**
   - Geocoding de direcciones
   - Cálculo de rutas y distancias
   - Visualización en mapas interactivos

