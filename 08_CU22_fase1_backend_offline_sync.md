# 08 - CU22 Fase 1: Backend offline-sync idempotente

## 1. Objetivo
Implementar soporte backend para sincronizar emergencias creadas offline desde Flutter mediante `POST /incidents/offline-sync`, con validación de cliente registrado, resolución de vehículo y control de idempotencia por `client_offline_id`.

## 2. Archivos modificados
- `backend/app/models.py`
- `backend/app/schemas.py`
- `backend/app/routers/incidents.py`
- `backend/main.py`
- `backend/migrations/2026_05_29_cu22_offline_sync.sql`

## 3. Cambios en base de datos
Se agregaron campos nullable en `incidents`:
- `client_offline_id`
- `client_email_offline`
- `created_offline_at`
- `synced_at`
- `sync_source`

Índices:
- índice simple: `idx_incidents_client_offline_id`
- índice parcial único: `idx_incidents_user_offline_unique` sobre `(user_id, client_offline_id)` cuando `client_offline_id IS NOT NULL`

## 4. Schemas agregados
En `backend/app/schemas.py`:
- `OfflineIncidentSyncRequest`
- `OfflineIncidentSyncResponse`

## 5. Endpoint implementado
- **Método:** `POST`
- **Ruta:** `/incidents/offline-sync`
- **JWT:** No requerido.

Comportamiento:
1. Valida payload obligatorio.
2. Busca usuario por correo.
3. Verifica rol `CLIENT`.
4. Revisa idempotencia por `(user_id, client_offline_id)`.
5. Resuelve vehículo por placa (reutiliza/crea/conflicto).
6. Crea incidente normal en `PENDING` con trazabilidad offline.
7. Crea `IncidentHistory` con nota: `Incidente sincronizado desde modo offline`.

## 6. Reglas de idempotencia
- Si ya existe un incidente con el mismo `user_id + client_offline_id`, no crea uno nuevo.
- Devuelve el existente con:
  - `created=false`
  - `idempotent=true`
  - mensaje de sincronización previa.

## 7. Reglas de usuario y vehículo
Usuario:
- Si correo no existe: `404`.
- Si existe pero rol distinto a `CLIENT`: `422`.

Vehículo:
- Si placa existe y pertenece al cliente: reutiliza.
- Si placa no existe: crea vehículo con `brand/model/year/plate`.
- Si placa existe pero pertenece a otro usuario: `409`.

## 8. Errores controlados
- `404`: `No existe un usuario registrado con ese correo`
- `422`: payload inválido o correo no cliente
- `409`: conflicto de placa

## 9. Qué no se modificó
- No se modificó `POST /incidents` normal.
- No se modificaron enums.
- No se tocaron pagos, Stripe, QR, ofertas, talleres ni mecánico.
- No se tocaron Flutter ni Angular.
- No se alteró CU25.

## 10. Prueba rápida con curl
```bash
curl -X POST http://localhost:8000/incidents/offline-sync \
  -H "Content-Type: application/json" \
  -d '{
    "client_offline_id": "offline-test-001",
    "client_email": "cliente@correo.com",
    "client_phone": "70000000",
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
  }'
```

## 11. Verificación en base de datos
```powershell
docker exec autogo_postgres psql -U autogo -d autogo_db -c "\d incidents"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, vehicle_id, status, client_offline_id, client_email_offline, sync_source, created_offline_at, synced_at FROM incidents ORDER BY id DESC LIMIT 20;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, brand, model, year, plate FROM vehicles ORDER BY id DESC LIMIT 20;"
```
