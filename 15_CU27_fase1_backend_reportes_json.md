# 15 - CU27 Fase 1: Backend reporte JSON por rol

## 1. Objetivo
Implementar el endpoint base de reportes operacionales en JSON para `ADMIN`, `WORKSHOP` y `CLIENT`, con filtros controlados por rol, sin tocar frontend ni exportaciones.

## 2. Archivos modificados
- `backend/app/routers/reports.py` (nuevo)
- `backend/app/schemas.py`
- `backend/main.py`

## 3. Endpoint implementado
- `POST /reports/operational/query`
- Requiere JWT (`get_current_user`).
- Tag: `reports`.

## 4. Roles soportados
- `admin`: acceso global con filtros ampliados.
- `workshop`: solo incidentes de su propio taller (`Workshop.owner_id == current_user.id`).
- `client`: solo incidentes propios (`Incident.user_id == current_user.id`).
- Otros roles (por ejemplo `technician`): `403`.

## 5. Filtros implementados
Request (`OperationalReportRequest`):
- `start_date`
- `end_date`
- `workshop_id`
- `incident_type` (contra `Incident.classification`)
- `status`
- `technician_id`
- `client_id`
- `vehicle_id`
- `payment_method`

Reglas:
- `start_date` y `end_date` filtran por `Incident.created_at`.
- `end_date` tipo fecha incluye todo el día (`time.max`).
- `incident_type` usa `classification` (no `description`).
- `payment_method` filtra por `Payment.payment_method`.

## 6. Reglas de seguridad por rol
- `ADMIN`: puede usar todos los filtros.
- `WORKSHOP`:
  - Scope forzado a su taller.
  - Ignora `workshop_id` enviado para ampliar alcance.
  - Si envía `technician_id`, se valida pertenencia al mismo taller.
  - Si no existe taller asociado al usuario: `404`.
- `CLIENT`:
  - Scope forzado a sus incidentes.
  - Ignora `workshop_id` y `client_id` enviados para ampliar alcance.
  - `vehicle_id` aplica dentro de su scope.

## 7. Estructura de respuesta
`OperationalReportResponse`:
- `role_scope`: `admin | workshop | client`
- `applied_filters`
- `summary`
- `items`

## 8. Cálculo de resumen
`OperationalReportSummary`:
- `total_incidents`
- Conteo por estado: `pending`, `waiting_offers`, `assigned`, `accepted`, `in_progress`, `completed`, `cancelled`
- `total_amount`: suma de `Payment.amount`
- `total_workshop_earnings`: suma de `Payment.workshop_earnings`
- `total_paid`: cantidad de pagos con `is_paid = true`
- `total_unpaid`: cantidad de pagos con `is_paid = false`

Si no hay pagos, los totales monetarios se devuelven en `0`.

## 9. Items del reporte
Cada item (`OperationalReportItem`) incluye:
- Identidad y fechas del incidente
- Estado, prioridad, clasificación
- Cliente (id, nombre, correo)
- Vehículo (id, marca, modelo, placa)
- Taller y técnico
- Pago asociado (id, monto, método, pagado, comisión, ganancia taller)

Visualización de tipo:
- Si `classification` viene vacío, se devuelve `Sin clasificar` en el item.

## 10. Qué no se implementó todavía
- No PDF.
- No Excel.
- No Web.
- No Flutter.
- No voz.
- La voz será obligatoria en una fase posterior para web y móvil, pero no en esta fase.

## 11. Cómo probar con curl
### 11.1 Admin
```bash
curl -X POST http://localhost:8000/reports/operational/query \
  -H "Authorization: Bearer <ADMIN_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "start_date": "2026-05-01",
    "end_date": "2026-05-31",
    "workshop_id": 1,
    "status": "completed",
    "incident_type": "battery",
    "technician_id": 2,
    "client_id": 5,
    "vehicle_id": 10,
    "payment_method": "transfer"
  }'
```

### 11.2 Workshop (incluyendo `workshop_id` malicioso)
```bash
curl -X POST http://localhost:8000/reports/operational/query \
  -H "Authorization: Bearer <WORKSHOP_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "workshop_id": 9999,
    "start_date": "2026-05-01",
    "end_date": "2026-05-31",
    "status": "completed",
    "technician_id": 2
  }'
```
Resultado esperado: solo incidentes del taller autenticado.

### 11.3 Client (incluyendo `client_id`/`workshop_id` malicioso)
```bash
curl -X POST http://localhost:8000/reports/operational/query \
  -H "Authorization: Bearer <CLIENT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": 9999,
    "workshop_id": 8888,
    "start_date": "2026-05-01",
    "end_date": "2026-05-31",
    "status": "completed",
    "vehicle_id": 3,
    "payment_method": "cash"
  }'
```
Resultado esperado: solo incidentes del cliente autenticado.

## 12. Verificación de permisos
Checks recomendados:
- Workshop A no debe ver incidentes de Workshop B aunque envíe `workshop_id` de B.
- Client A no debe ver incidentes de Client B aunque envíe `client_id` de B.
- `technician` debe recibir `403`.
- `workshop` con `technician_id` de otro taller debe recibir `403`.

Comando BD útil:
```bash
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, workshop_id, technician_id, status, classification, created_at, completed_at FROM incidents ORDER BY id DESC LIMIT 20;"
```

## 13. Pendientes para Fase 2
- Implementar exportación PDF usando este mismo payload/base de consulta.
- Implementar exportación Excel usando el mismo payload/base de consulta.
- Definir formato final de exportables (hoja Resumen + Detalle para Excel).
