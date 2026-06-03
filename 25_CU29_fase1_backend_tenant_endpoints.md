# 25 - CU29 Fase 1: Backend endpoints tenant

## 1. Objetivo
Implementar endpoints backend nuevos, aislados y específicos para CU29 bajo el prefijo `/admin/tenant`.

El objetivo es dejar un contrato estable para Angular admin sin modificar ni parchar endpoints existentes.

## 2. Decisión de usar /admin/tenant
Se creó un router nuevo:

`backend/app/routers/admin_tenant.py`

Prefijo:

`/admin/tenant`

Esto evita mezclar el CU29 con endpoints legacy de `/admin`, `/workshops` o `/technicians`.

## 3. Tenant = Workshop
En AUTOGO:

`tenant = Workshop/Taller`

No se creó entidad `Tenant`, no se crearon sucursales, no se agregaron especialidades y no se agregaron servicios ofrecidos.

## 4. Archivos modificados
- `backend/app/routers/admin_tenant.py`
- `backend/app/schemas.py`
- `backend/main.py`
- `25_CU29_fase1_backend_tenant_endpoints.md`

## 5. Router nuevo
Router:

```python
APIRouter(prefix="/admin/tenant", tags=["admin-tenant"])
```

Registro:

```python
app.include_router(admin_tenant.router)
```

## 6. Schemas nuevos
Schemas agregados:
- `TenantWorkshopResponse`
- `TenantWorkshopCreate`
- `TenantWorkshopUpdate`
- `TenantWorkshopStatusUpdate`
- `TenantWorkshopOwnerOption`
- `TenantWorkshopUserRow`
- `TenantTechnicianCreate`
- `TenantTechnicianUpdate`
- `TenantTechnicianStatusUpdate`

## 7. Endpoints creados
- `GET /admin/tenant/workshops`
- `GET /admin/tenant/workshops/{workshop_id}`
- `GET /admin/tenant/workshop-owners`
- `POST /admin/tenant/workshops`
- `PUT /admin/tenant/workshops/{workshop_id}`
- `PATCH /admin/tenant/workshops/{workshop_id}/status`
- `GET /admin/tenant/workshops/{workshop_id}/users`
- `POST /admin/tenant/workshops/{workshop_id}/technicians`
- `PUT /admin/tenant/technicians/{technician_id}`
- `PATCH /admin/tenant/technicians/{technician_id}/status`

## 8. Contratos JSON
### GET /admin/tenant/workshops
Query params:
- `search`
- `is_active`
- `skip`
- `limit`

Response:

```json
[
  {
    "id": 1,
    "name": "Taller Pegaso",
    "address": "Av. Ejemplo",
    "latitude": -17.78,
    "longitude": -63.18,
    "commission_percentage": 10.0,
    "is_active": true,
    "owner_id": 3,
    "owner_name": "Seiya Caballero Pegaso",
    "owner_email": "taller2@gmail.com",
    "owner_phone": "70000000",
    "technician_count": 2,
    "active_technician_count": 2,
    "created_at": "2026-05-29T10:30:00",
    "updated_at": "2026-05-29T10:30:00"
  }
]
```

### GET /admin/tenant/workshops/{workshop_id}
Response:

```json
{
  "id": 1,
  "name": "Taller Pegaso",
  "address": "Av. Ejemplo",
  "latitude": -17.78,
  "longitude": -63.18,
  "commission_percentage": 10.0,
  "is_active": true,
  "owner_id": 3,
  "owner_name": "Seiya Caballero Pegaso",
  "owner_email": "taller2@gmail.com",
  "owner_phone": "70000000",
  "technician_count": 2,
  "active_technician_count": 2,
  "created_at": "2026-05-29T10:30:00",
  "updated_at": "2026-05-29T10:30:00"
}
```

### GET /admin/tenant/workshop-owners
Response:

```json
[
  {
    "id": 3,
    "full_name": "Taller Owner",
    "email": "taller@gmail.com",
    "phone": "70000000",
    "role": "workshop",
    "has_workshop": true,
    "workshop_id": 1
  },
  {
    "id": 8,
    "full_name": "Nuevo Dueño",
    "email": "nuevo@gmail.com",
    "phone": "70000001",
    "role": "workshop",
    "has_workshop": false,
    "workshop_id": null
  }
]
```

### POST /admin/tenant/workshops
Request:

```json
{
  "owner_id": 8,
  "name": "Taller Nuevo",
  "address": "Av. Ejemplo",
  "latitude": -17.78,
  "longitude": -63.18,
  "commission_percentage": 10,
  "is_active": true
}
```

Response:

```json
{
  "id": 10,
  "name": "Taller Nuevo",
  "address": "Av. Ejemplo",
  "latitude": -17.78,
  "longitude": -63.18,
  "commission_percentage": 10.0,
  "is_active": true,
  "owner_id": 8,
  "owner_name": "Nuevo Dueño",
  "owner_email": "nuevo@gmail.com",
  "owner_phone": "70000001",
  "technician_count": 0,
  "active_technician_count": 0,
  "created_at": "2026-05-29T10:30:00",
  "updated_at": "2026-05-29T10:30:00"
}
```

### PUT /admin/tenant/workshops/{workshop_id}
Request:

```json
{
  "name": "Taller Editado",
  "address": "Nueva dirección",
  "latitude": -17.8,
  "longitude": -63.2,
  "commission_percentage": 15,
  "is_active": true
}
```

Response:

```json
{
  "id": 1,
  "name": "Taller Editado",
  "address": "Nueva dirección",
  "latitude": -17.8,
  "longitude": -63.2,
  "commission_percentage": 15.0,
  "is_active": true,
  "owner_id": 3,
  "owner_name": "Seiya Caballero Pegaso",
  "owner_email": "taller2@gmail.com",
  "owner_phone": "70000000",
  "technician_count": 2,
  "active_technician_count": 2,
  "created_at": "2026-05-29T10:30:00",
  "updated_at": "2026-05-29T10:30:00"
}
```

### PATCH /admin/tenant/workshops/{workshop_id}/status
Request:

```json
{
  "is_active": false
}
```

Response:

```json
{
  "id": 1,
  "name": "Taller Pegaso",
  "address": "Av. Ejemplo",
  "latitude": -17.78,
  "longitude": -63.18,
  "commission_percentage": 10.0,
  "is_active": false,
  "owner_id": 3,
  "owner_name": "Seiya Caballero Pegaso",
  "owner_email": "taller2@gmail.com",
  "owner_phone": "70000000",
  "technician_count": 2,
  "active_technician_count": 2,
  "created_at": "2026-05-29T10:30:00",
  "updated_at": "2026-05-29T10:30:00"
}
```

### GET /admin/tenant/workshops/{workshop_id}/users
Response:

```json
[
  {
    "row_type": "owner",
    "relation": "Dueño del taller",
    "user_id": 3,
    "technician_id": null,
    "workshop_id": 1,
    "full_name": "Seiya Caballero Pegaso",
    "email": "taller2@gmail.com",
    "phone": "70000000",
    "role": "workshop",
    "is_active": true,
    "is_available": null,
    "access_code": null
  },
  {
    "row_type": "technician",
    "relation": "Técnico del taller",
    "user_id": 20,
    "technician_id": 4,
    "workshop_id": 1,
    "full_name": "Mecánico 2",
    "email": "mecanico2@gmail.com",
    "phone": "70000001",
    "role": "technician",
    "is_active": true,
    "is_available": true,
    "access_code": "ABC123"
  }
]
```

### POST /admin/tenant/workshops/{workshop_id}/technicians
Request:

```json
{
  "full_name": "Mecánico 3",
  "email": "mecanico3@gmail.com",
  "password": "Temporal123",
  "phone": "70000000",
  "is_active": true,
  "is_available": true
}
```

Response:

```json
{
  "row_type": "technician",
  "relation": "Técnico del taller",
  "user_id": 21,
  "technician_id": 8,
  "workshop_id": 1,
  "full_name": "Mecánico 3",
  "email": "mecanico3@gmail.com",
  "phone": "70000000",
  "role": "technician",
  "is_active": true,
  "is_available": true,
  "access_code": "ABC123"
}
```

### PUT /admin/tenant/technicians/{technician_id}
Request:

```json
{
  "full_name": "Mecánico Editado",
  "phone": "70000000",
  "is_active": true,
  "is_available": false
}
```

Response:

```json
{
  "row_type": "technician",
  "relation": "Técnico del taller",
  "user_id": 21,
  "technician_id": 8,
  "workshop_id": 1,
  "full_name": "Mecánico Editado",
  "email": "mecanico3@gmail.com",
  "phone": "70000000",
  "role": "technician",
  "is_active": true,
  "is_available": false,
  "access_code": "ABC123"
}
```

### PATCH /admin/tenant/technicians/{technician_id}/status
Request:

```json
{
  "is_active": false
}
```

Response:

```json
{
  "row_type": "technician",
  "relation": "Técnico del taller",
  "user_id": 21,
  "technician_id": 8,
  "workshop_id": 1,
  "full_name": "Mecánico Editado",
  "email": "mecanico3@gmail.com",
  "phone": "70000000",
  "role": "technician",
  "is_active": false,
  "is_available": false,
  "access_code": "ABC123"
}
```

## 9. Validaciones
- Todos los endpoints requieren ADMIN.
- Crear taller valida que `owner_id` exista.
- Crear taller valida que `owner_id` tenga rol `workshop`.
- Crear taller valida que el owner no tenga otro taller.
- Crear/editar taller valida `commission_percentage` entre 0 y 100.
- Crear técnico valida taller existente.
- Crear técnico valida email único.
- Editar técnico no permite cambiar `workshop_id`, `user_id` ni `access_code`.
- Desactivar técnico fuerza `is_available = false`.

## 10. Seguridad por rol ADMIN
Todos los endpoints usan `get_current_user` y validan:

```python
current_user.role == UserRole.ADMIN
```

Usuarios no administradores reciben `403`.

## 11. Endpoints existentes que NO se tocaron
No se modificaron endpoints existentes de:
- `/admin/workshops`
- `/admin/users`
- `/admin/technicians`
- `/workshops`
- `/technicians`
- `/reports`
- `/payments`
- `/incidents`
- `/offers`
- `/technician`

El nuevo flujo CU29 queda aislado en `/admin/tenant`.

## 12. Cómo probar en Swagger
1. Iniciar sesión como admin.
2. Copiar token JWT.
3. Abrir Swagger en `http://localhost:8000/docs`.
4. Autorizar con Bearer token.
5. Probar:
   - `GET /admin/tenant/workshops`
   - `GET /admin/tenant/workshop-owners`
   - `POST /admin/tenant/workshops`
   - `PUT /admin/tenant/workshops/{workshop_id}`
   - `PATCH /admin/tenant/workshops/{workshop_id}/status`
   - `GET /admin/tenant/workshops/{workshop_id}/users`
   - `POST /admin/tenant/workshops/{workshop_id}/technicians`
   - `PUT /admin/tenant/technicians/{technician_id}`
   - `PATCH /admin/tenant/technicians/{technician_id}/status`

Casos esperados:
- `GET /admin/tenant/workshops` devuelve `technician_count`.
- `GET /admin/tenant/workshop-owners` devuelve `has_workshop`.
- Crear taller con owner disponible funciona.
- Crear taller con owner ocupado devuelve `409`.
- Editar taller no cambia owner.
- Desactivar técnico también pone `is_available = false`.

## 13. Pendientes para Angular Fase 2
- Actualizar `AdminService` para consumir `/admin/tenant`.
- Rehacer `/admin/gestion-talleres`.
- Reutilizar `app-map-picker` para crear/editar taller.
- Mostrar `technician_count` sin llamadas extra por fila.
- Usar `GET /admin/tenant/workshop-owners` para select de owner.
- Usar `technician_id` para acciones de técnicos.
- Mantener owner por `user_id`.
