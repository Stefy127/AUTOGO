# 07 - Diagnóstico CU22: Emergencia offline y sincronización

## 1. Resumen del flujo esperado
1. El cliente sin internet debe poder abrir una opción visible `Emergencia offline` sin autenticación.
2. Completa un formulario local con correo, vehículo, descripción y ubicación.
3. La emergencia se guarda localmente con estado de sincronización (`pending/syncing/failed/synced`).
4. Al recuperar conexión, la app sincroniza contra backend con `client_offline_id` idempotente.
5. Solo tras sincronizar con éxito se crea la emergencia real en backend y recién ahí se vuelve visible para talleres.
6. Si falla la sincronización, la emergencia queda local en `failed` con reintento manual.

## 2. Decisiones funcionales cerradas
- El cliente debe estar registrado previamente en AUTOGO.
- La pantalla `Emergencia offline` puede usarse sin login, pero al sincronizar el backend debe validar que el correo pertenece a un usuario existente con rol `CLIENT`.
- No se crean usuarios automáticamente.
- No se crean clientes invitados.
- Si el correo no existe, la sincronización falla con error controlado y la emergencia local queda en `failed`.
- Si el correo existe pero no tiene rol `CLIENT`, la sincronización falla con error controlado.
- La emergencia offline no se vuelve visible para talleres hasta que se sincronice correctamente.
- Solo puede existir una emergencia offline activa por dispositivo con estado `pending`, `syncing` o `failed`.
- Si el usuario intenta crear otra emergencia offline mientras ya existe una activa, no se crea otra; se muestra la existente para editar, eliminar o reintentar.
- El backend debe usar `client_offline_id` para evitar duplicados en reintentos.
- No tocar pagos, Stripe, QR, ofertas, talleres, mecánico ni CU25.

## 3. Estado actual del backend para creación de emergencias
Estado actual identificado:
- Endpoint vigente: `POST /incidents` en `backend/app/routers/incidents.py`.
- Requiere JWT (`current_user = Depends(get_current_active_user)`).
- Schema de entrada: `IncidentCreate` (`backend/app/schemas.py`) exige `vehicle_id` + `description` (y opcionales de ubicación/media).
- Validación crítica: el `vehicle_id` debe pertenecer al usuario autenticado.
- `user_id` se asigna automáticamente desde `current_user.id`.
- Estado inicial creado: `IncidentStatus.PENDING`.
- Se crea `IncidentHistory` con nota `Incidente creado`.
- No existe `POST /incidents/offline-sync` ni lógica idempotente por `client_offline_id`.
- No existen campos offline en `incidents` (`client_offline_id`, `sync_source`, etc.).

Impacto CU22:
- Con arquitectura actual no se puede crear emergencia sin login ni sin vehículo previamente creado.

## 4. Estado actual de usuarios, clientes y vehículos
### Usuarios/clientes
- Modelo `User` (`backend/app/models.py`) tiene `email` único global y `role` (`client/workshop/technician/admin`).
- El correo existe como identificador adecuado para sincronización offline.
- No hay endpoint público para lookup de correo de cliente.

### Vehículos
- Modelo `Vehicle` requiere: `brand`, `model`, `year`, `plate`, `user_id`.
- `plate` es `unique=True` global (no por usuario).
- Endpoint actual `POST /vehicles` exige JWT y rechaza placa duplicada globalmente.
- Creación de incidente normal exige `vehicle_id` existente, no datos de vehículo en el payload de incidente.

Impacto CU22:
- Para offline-sync, backend debe resolver: buscar cliente por correo y luego buscar/crear vehículo por placa con reglas explícitas de conflicto.

## 5. Estado actual de Flutter para creación de emergencias
Archivos relevantes revisados:
- `movile_front/lib/main.dart`
- `movile_front/lib/screens/login_screen.dart`
- `movile_front/lib/screens/home_screen.dart`
- `movile_front/lib/screens/emergency_form_screen.dart`
- `movile_front/lib/services/api_service.dart`
- `movile_front/lib/services/auth_service.dart`

Hallazgos:
- `initialRoute` es `/login`; no existe ruta/pantalla `EmergencyOfflineScreen`.
- `LoginScreen` solo ofrece login, registro y acceso de técnico; no botón offline.
- `HomeScreen` requiere usuario autenticado y navega a `'/emergency-form'`.
- `EmergencyFormScreen` carga vehículos desde API (`GET /vehicles`) y al enviar usa `POST /incidents` con `vehicle_id`.
- `ApiService` no tiene cola offline ni estrategia de sincronización.

Impacto CU22:
- UI y flujo actual están orientados a modo online autenticado.

## 6. Estado actual de almacenamiento local y conectividad
En `pubspec.yaml`:
- Ya existe `shared_preferences` (apto para persistir JSON simple de emergencia offline).
- No se encontró `connectivity_plus`.
- `AuthService` ya usa `shared_preferences` para token; no hay estructura para emergencias offline.

Conclusión:
- Para CU22, la opción mínima y coherente es `shared_preferences` con JSON para una sola emergencia offline activa.
- En primera versión se prioriza sincronización manual (`Sincronizar`/`Reintentar`).
- La sincronización automática queda como mejora posterior.

## 7. Brecha funcional del CU22
Brechas concretas frente al objetivo:
- No existe modo de creación de emergencia sin login.
- No existe formulario offline desacoplado de `vehicle_id` backend.
- No existe almacenamiento local de emergencia pendiente.
- No existe regla de una sola emergencia offline activa.
- No existe endpoint backend idempotente offline-sync.
- No existen campos de trazabilidad offline en `incidents`.
- No existe manejo de errores de sincronización con estado persistente.

## 8. Diseño recomendado para emergencia offline
### Estructura local propuesta (JSON)
- `local_id` (uuid local)
- `client_offline_id` (uuid estable para idempotencia backend)
- `client_email`
- `client_phone` (opcional)
- `vehicle_brand`
- `vehicle_model`
- `vehicle_year`
- `vehicle_plate`
- `incident_type`
- `description`
- `address`
- `latitude`, `longitude` (opcionales)
- `created_offline_at`
- `sync_status` (`pending|syncing|failed|synced`)
- `sync_attempts`
- `last_error`
- `backend_incident_id` (nullable)
- `synced_at` (nullable)

### Justificación de campos de vehículo
El formulario offline no debe usar solo `vehicle_name`. Debe pedir `vehicle_brand`, `vehicle_model`, `vehicle_year`, `vehicle_plate` para ser compatible con el modelo actual `Vehicle`, que requiere:
- `brand`
- `model`
- `year`
- `plate`
- `user_id`

Esto evita inventar datos al crear vehículo durante la sincronización.

### Flujo recomendado
1. Usuario entra a `Emergencia offline` sin sesión.
2. Se valida si ya hay emergencia activa local.
3. Si no hay, se crea en `pending`.
4. Si hay internet y usuario presiona sincronizar, se envía a `POST /incidents/offline-sync`.
5. Éxito: estado `synced` + `backend_incident_id`.
6. Falla: estado `failed` + mensaje.

## 9. Diseño anti-duplicados local
Regla obligatoria:
- Antes de crear nueva emergencia offline, buscar en storage local emergencia con estado `pending`, `syncing` o `failed`.
- Si existe, bloquear alta nueva y abrir detalle de la existente.

Acciones disponibles sobre existente:
- Ver
- Editar
- Eliminar localmente
- Reintentar sincronización

Estado `synced`:
- Puede limpiarse tras confirmación o conservarse como historial local mínimo.

## 10. Diseño anti-duplicados backend
Propuesta idempotente:
- Agregar en `incidents`:
  - `client_offline_id` nullable
  - `client_email_offline` nullable
  - `created_offline_at` nullable
  - `synced_at` nullable
  - `sync_source` nullable (ej. `offline`)
- Índice único recomendado (parcial): `UNIQUE(user_id, client_offline_id) WHERE client_offline_id IS NOT NULL`.

Comportamiento:
- Si llega `(user_id, client_offline_id)` ya existente, devolver incidente existente y no crear duplicado.
- Si no existe, crear incidente normal con trazabilidad offline.

## 11. Endpoint propuesto para sincronización offline
### Método y ruta
- `POST /incidents/offline-sync`

### Autenticación
- Sin JWT (público con validaciones de negocio y datos).

### Body recomendado
```json
{
  "client_offline_id": "uuid-generado-en-flutter",
  "client_email": "cliente@correo.com",
  "client_phone": "opcional",
  "vehicle_brand": "Toyota",
  "vehicle_model": "Corolla",
  "vehicle_year": 2015,
  "vehicle_plate": "ABC-123",
  "incident_type": "battery",
  "description": "El auto no enciende",
  "address": "Zona Equipetrol",
  "latitude": -17.78,
  "longitude": -63.18,
  "created_offline_at": "2026-05-29T10:30:00"
}
```

### Validaciones
1. Campos mínimos presentes.
2. `client_email` válido.
3. Usuario por correo existe.
4. Usuario por correo tiene rol `CLIENT`.
5. Reglas de vehículo:
   - Buscar usuario por correo.
   - Buscar vehículo por placa.
   - Si la placa existe y pertenece al cliente encontrado: reutilizar vehículo.
   - Si la placa no existe: crear vehículo para ese cliente usando `brand/model/year/plate`.
   - Si la placa existe pero pertenece a otro usuario: devolver `409 Conflict`.
   - No crear vehículo duplicado si ya existe para ese cliente.
6. Idempotencia por `(user_id, client_offline_id)`.

### Qué crea/modifica
- Crea `Incident` normal (`status=PENDING`) con `user_id` y `vehicle_id` resueltos.
- Registra `IncidentHistory`.
- Guarda metadatos offline en campos nuevos.

### Respuestas y errores
- `201` creado nuevo.
- `200` incidente existente por idempotencia.
- `404` correo no encontrado.
- `422` correo no es cliente / payload inválido.
- `409` conflicto de placa.
- `500` error interno.

## 12. Cambios de base de datos propuestos
Recomendación inicial: **extender `incidents`** (no tabla nueva), porque la sincronización debe desembocar en una emergencia normal.

Campos sugeridos en `incidents`:
- `client_offline_id` varchar nullable
- `client_email_offline` varchar nullable
- `created_offline_at` timestamp nullable
- `synced_at` timestamp nullable
- `sync_source` varchar nullable

Índices sugeridos:
- `UNIQUE(user_id, client_offline_id)` parcial cuando `client_offline_id IS NOT NULL`
- índice simple `client_offline_id`
- índice opcional `sync_source`

## 13. Cambios de backend propuestos
- Nuevos schemas en `backend/app/schemas.py`:
  - `OfflineIncidentSyncRequest`
  - `OfflineIncidentSyncResponse`
- Nuevo endpoint en `backend/app/routers/incidents.py`:
  - `POST /incidents/offline-sync` (sin JWT)
- Lógica de resolución de usuario/vehículo:
  - buscar `User` por email
  - validar rol `CLIENT`
  - buscar/reusar/crear vehículo según reglas de placa
- Lógica idempotente por `client_offline_id`.
- Registrar historial y mantener flujo normal de incidentes.
- Sin cambios en ofertas, pagos, QR, Stripe, talleres, técnico ni CU25.

## 14. Cambios de Flutter propuestos
1. Nueva pantalla `EmergencyOfflineScreen` accesible sin login.
2. Formulario offline con:
   - `client_email`
   - `client_phone` opcional
   - `vehicle_brand`
   - `vehicle_model`
   - `vehicle_year`
   - `vehicle_plate`
   - datos de emergencia y ubicación
3. Persistencia local con `shared_preferences` (JSON único).
4. Regla de una sola emergencia activa (`pending/syncing/failed`).
5. Vista de estado con acciones:
   - editar
   - eliminar local
   - reintentar
6. Sincronización manual como primera versión (`Sincronizar` / `Reintentar`).
7. Sincronización automática como mejora posterior.

## 15. Comandos útiles de verificación
```powershell
docker exec autogo_postgres psql -U autogo -d autogo_db -c "\d incidents"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "\d vehicles"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, email, role, created_at FROM users ORDER BY id DESC LIMIT 30;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, brand, model, year, plate, created_at FROM vehicles ORDER BY id DESC LIMIT 30;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, vehicle_id, status, description, location_text, created_at FROM incidents ORDER BY id DESC LIMIT 30;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT t.typname, e.enumlabel FROM pg_type t JOIN pg_enum e ON t.oid = e.enumtypid WHERE t.typname='incidentstatus' ORDER BY e.enumsortorder;"
```

Comandos para cuando se implemente CU22:
```powershell
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, client_offline_id, client_email_offline, sync_source, created_offline_at, synced_at FROM incidents ORDER BY id DESC LIMIT 30;"
```

## 16. Riesgos y dudas antes de implementar
1. ¿El endpoint offline-sync será totalmente público o con control antiabuso (rate limit/captcha futuro)?
2. ¿Qué validación mínima de correo se exige además del formato?
3. Si el correo existe pero no es `client`, ¿se devuelve `422` o `403`?
4. Dado que `vehicles.plate` es único global, ¿qué política exacta tomar si la placa existe en otro usuario?
5. ¿Sincronización manual primero y automática después (confirmado para primera versión)?
6. ¿Después de `synced` se elimina local o se conserva historial?
7. En Flutter Web, ¿cómo se definirá la simulación offline para QA (DevTools network offline)?
8. ¿Qué mensaje UX exacto mostrar cuando backend rechaza por correo inexistente o por rol inválido?
9. ¿Qué hacer si la app cierra durante `syncing` (rollback a `failed` o retomar `syncing`)?
10. ¿Qué sucede si cambia de dispositivo? (la emergencia local no migra; esperado en este CU).

## 17. Criterios de aceptación
1. Existe acceso a `Emergencia offline` sin login.
2. Se puede registrar emergencia sin internet.
3. La emergencia se guarda localmente.
4. Solo puede existir una emergencia offline activa (`pending/syncing/failed`).
5. Si intenta crear otra, se muestra la existente.
6. Se puede editar/eliminar/reintentar la emergencia local.
7. Al volver internet, sincroniza contra backend mediante acción manual.
8. Si correo existe y es cliente, se crea incidente real.
9. Si correo no existe, falla con error controlado y queda en `failed`.
10. Si correo existe pero no es cliente, falla con error controlado y queda en `failed`.
11. Si vehículo no existe, se crea con `brand/model/year/plate`; si existe para ese cliente se reutiliza.
12. Reintento con mismo `client_offline_id` no duplica incidente.
13. Si la placa existe en otro usuario, backend devuelve `409`.
14. Talleres ven emergencia solo después de sincronización exitosa.
15. No se rompe `POST /incidents` normal ni flujos de ofertas/pagos/Stripe/QR/mecánico.

## 18. Plan de implementación por fases
1. **Fase 1 - Backend offline-sync idempotente.**
2. **Fase 2 - Pantalla Flutter “Emergencia offline”.**
3. **Fase 3 - Guardado local con una sola emergencia activa.**
4. **Fase 4 - Sincronización manual y manejo de estados.**
5. **Fase 5 - UI de edición, eliminación, reintento y errores.**
6. **Fase 6 - Pruebas anti-duplicado y regresión.**
7. **Fase 7 - Documentación final.**
