# 24 - CU29 Contrato JSON de endpoints admin

## 1. Objetivo del documento
Definir el contrato JSON real de los endpoints admin que se usarán en CU29 antes de continuar la implementación. El objetivo es saber exactamente qué recibe y devuelve el backend, qué debe mostrar Angular y qué brechas deben corregirse en Fase 1.

## 2. Alcance del contrato
CU29 trabaja con `tenant = Workshop/Taller`. No existe entidad `Tenant` separada.

Incluye:
- Gestión admin de talleres.
- Gestión admin de usuarios/técnicos asociados al taller.
- Contratos JSON para Angular admin.

No incluye:
- Sucursales.
- Especialidades.
- Servicios ofrecidos.
- Flutter.
- CU22, CU25, CU27.
- Pagos, Stripe, QR, reportes o voz.

## 3. Resumen de endpoints
| Endpoint | Método | Uso CU29 | Estado |
|---|---|---|---|
| `/admin/workshops` | GET | Tabla principal | Usable |
| `/admin/workshops/{workshop_id}` | GET | Detalle taller | Usable |
| `/admin/workshops` | POST | Crear taller | Requiere corrección schema |
| `/admin/workshops/{workshop_id}` | PUT | Editar taller | Usable |
| `/admin/workshops/{workshop_id}/activate` | PATCH | Activar/desactivar taller | Usable |
| `/admin/workshops/{workshop_id}/users` | GET | Usuarios/técnicos del taller | Usable |
| `/admin/workshops/{workshop_id}/users` | POST | Crear técnico con usuario | Usable con alcance acotado |
| `/admin/technicians/{technician_id}` | PUT | Editar técnico | Usable |
| `/admin/technicians/{technician_id}/status` | PATCH | Activar/desactivar técnico | Usable |
| `/admin/users?role=workshop` | GET | Seleccionar owner | Usable |
| `/admin/users/{user_id}` | PATCH | Editar usuario owner | Usable con cuidado |
| `/admin/users/{user_id}/status` | PATCH | Cambiar estado owner/técnico con user | Usable con cuidado |

## 4. Contrato: GET /admin/workshops
### Método y ruta
`GET /admin/workshops`

### Rol requerido
ADMIN.

### Query params
- `skip`: int, default `0`.
- `limit`: int, default `100`.
- `is_active`: boolean opcional.

### Request
```json
{}
```

### Response
Devuelve `List[WorkshopResponse]`.

```json
[
  {
    "name": "Taller Pegaso",
    "address": "Av. Ejemplo",
    "latitude": -17.78,
    "longitude": -63.18,
    "commission_percentage": 10.0,
    "is_active": true,
    "id": 1,
    "owner_id": 3,
    "created_at": "2026-05-29T10:30:00",
    "updated_at": "2026-05-29T10:30:00",
    "owner": {
      "email": "taller@gmail.com",
      "full_name": "Taller Owner",
      "phone": "70000000",
      "role": "workshop",
      "id": 3,
      "created_at": "2026-05-29T10:30:00",
      "updated_at": "2026-05-29T10:30:00"
    }
  }
]
```

### Campos importantes para Angular
- `id`
- `name`
- `owner_id`
- `owner.full_name`
- `owner.email`
- `address`
- `latitude`
- `longitude`
- `commission_percentage`
- `is_active`

### Campos deseados que no vienen actualmente
- `technician_count`: no viene actualmente. Debe calcularse en frontend llamando `GET /admin/workshops/{id}/users` o agregarse en Fase 1.
- `owner_name`: no viene como campo plano; viene como `owner.full_name`.
- `owner_email`: no viene como campo plano; viene como `owner.email`.

### Errores posibles
- `403`: usuario no ADMIN.

### Uso recomendado en CU29
Sí. Sirve para tabla principal, pero para técnicos por fila conviene agregar `technician_count` en backend o calcularlo temporalmente.

## 5. Contrato: GET /admin/workshops/{workshop_id}
### Método y ruta
`GET /admin/workshops/{workshop_id}`

### Rol requerido
ADMIN.

### Path params
- `workshop_id`: int.

### Request
```json
{}
```

### Response
Devuelve `WorkshopResponse`.

```json
{
  "name": "Taller Pegaso",
  "address": "Av. Ejemplo",
  "latitude": -17.78,
  "longitude": -63.18,
  "commission_percentage": 10.0,
  "is_active": true,
  "id": 1,
  "owner_id": 3,
  "created_at": "2026-05-29T10:30:00",
  "updated_at": "2026-05-29T10:30:00",
  "owner": {
    "email": "taller@gmail.com",
    "full_name": "Taller Owner",
    "phone": "70000000",
    "role": "workshop",
    "id": 3,
    "created_at": "2026-05-29T10:30:00",
    "updated_at": "2026-05-29T10:30:00"
  }
}
```

### Campos disponibles
Incluye datos principales del taller y `owner`.

### Campos que no trae
- No trae técnicos.
- No trae `technician_count`.
- No trae usuarios asociados. Para eso usar `GET /admin/workshops/{workshop_id}/users`.

### Errores posibles
- `403`: usuario no ADMIN.
- `404`: taller no encontrado.

### Uso recomendado en CU29
Sí. Usarlo para detalle de taller.

## 6. Contrato: POST /admin/workshops
### Método y ruta
`POST /admin/workshops`

### Rol requerido
ADMIN.

### Request esperado para CU29
```json
{
  "owner_id": 2,
  "name": "Taller Nuevo",
  "address": "Av. Ejemplo",
  "latitude": -17.78,
  "longitude": -63.18,
  "commission_percentage": 10,
  "is_active": true
}
```

### Request real según schema actual
Actualmente el endpoint usa `WorkshopCreate`, que contiene:

```json
{
  "name": "Taller Nuevo",
  "address": "Av. Ejemplo",
  "latitude": -17.78,
  "longitude": -63.18,
  "commission_percentage": 10,
  "is_active": true
}
```

### Brecha crítica
El endpoint implementado intenta leer `payload.owner_id`, pero `WorkshopCreate` no declara `owner_id`. Esto puede producir error en runtime o ignorar el campo según configuración de Pydantic. Para CU29 Fase 1 se recomienda crear un schema admin específico, por ejemplo `AdminWorkshopCreate`, con `owner_id` obligatorio.

### Response esperado
Devuelve `WorkshopResponse`.

```json
{
  "name": "Taller Nuevo",
  "address": "Av. Ejemplo",
  "latitude": -17.78,
  "longitude": -63.18,
  "commission_percentage": 10.0,
  "is_active": true,
  "id": 10,
  "owner_id": 2,
  "created_at": "2026-05-29T10:30:00",
  "updated_at": "2026-05-29T10:30:00",
  "owner": null
}
```

### Validaciones existentes en código
- Busca `owner_id`.
- Valida que el usuario exista.
- Valida que el usuario tenga rol `workshop`.
- Valida que el owner no tenga ya otro taller.

### Errores posibles
- `403`: usuario no ADMIN.
- `404`: owner no encontrado.
- `422`: owner no tiene rol `workshop`.
- `409`: owner ya tiene taller.
- Error interno si `owner_id` no existe en el schema.

### Uso recomendado en CU29
Sí, pero solo después de corregir schema en Fase 1.

## 7. Contrato: PUT /admin/workshops/{workshop_id}
### Método y ruta
`PUT /admin/workshops/{workshop_id}`

### Rol requerido
ADMIN.

### Path params
- `workshop_id`: int.

### Request
Usa `WorkshopUpdate`. Todos los campos son opcionales.

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

### Campos aceptados
- `name`
- `address`
- `latitude`
- `longitude`
- `commission_percentage`
- `is_active`

### Campos que no acepta
- `owner_id` no está en `WorkshopUpdate`.

### Response
Devuelve `WorkshopResponse`.

### Errores posibles
- `403`: usuario no ADMIN.
- `404`: taller no encontrado.

### Uso recomendado en CU29
Sí. Usar para editar información del taller. No cambiar owner en esta fase.

## 8. Contrato: PATCH /admin/workshops/{workshop_id}/activate
### Método y ruta
`PATCH /admin/workshops/{workshop_id}/activate`

### Rol requerido
ADMIN.

### Path params
- `workshop_id`: int.

### Query params
- `is_active`: boolean obligatorio.

### Request exacto
```http
PATCH /admin/workshops/2/activate?is_active=false
```

Body vacío:
```json
{}
```

### Response
```json
{
  "message": "Taller desactivado exitosamente",
  "workshop_id": 2,
  "is_active": false
}
```

### Errores posibles
- `403`: usuario no ADMIN.
- `404`: taller no encontrado.

### Uso recomendado en CU29
Sí. Mantener para toggle rápido en tabla.

## 9. Contrato: GET /admin/workshops/{workshop_id}/users
### Método y ruta
`GET /admin/workshops/{workshop_id}/users`

### Rol requerido
ADMIN.

### Path params
- `workshop_id`: int.

### Request
```json
{}
```

### Response
Devuelve lista unificada `AdminWorkshopUserResponse`.

```json
[
  {
    "user_id": 3,
    "full_name": "Seiya Caballero Pegaso",
    "email": "taller2@gmail.com",
    "phone": "70000000",
    "role": "workshop",
    "relation": "owner",
    "workshop_id": 1,
    "technician_id": null,
    "is_active": true,
    "is_available": null,
    "access_code": null
  },
  {
    "user_id": null,
    "full_name": "Mecánico 2",
    "email": null,
    "phone": "70000001",
    "role": "technician",
    "relation": "technician",
    "workshop_id": 1,
    "technician_id": 4,
    "is_active": true,
    "is_available": true,
    "access_code": "ABC123"
  }
]
```

### Comportamiento real
- Incluye owner si existe.
- Incluye técnicos del taller.
- Técnicos pueden venir con `user_id` null.
- Técnicos deben traer `technician_id`.
- `is_active` para owner representa `Workshop.is_active`.
- `is_active` para técnico representa `Technician.is_active`.

### Campos importantes para Angular
- `relation`
- `user_id`
- `technician_id`
- `full_name`
- `email`
- `phone`
- `role`
- `is_active`
- `is_available`
- `access_code`

### ID correcto para acciones
- Owner: usar `user_id`.
- Technician: usar `technician_id`.

### Errores posibles
- `403`: usuario no ADMIN.
- `404`: taller no encontrado.

### Uso recomendado en CU29
Sí. Es el endpoint principal para detalle del taller.

## 10. Contrato: POST /admin/workshops/{workshop_id}/users
### Método y ruta
`POST /admin/workshops/{workshop_id}/users`

### Rol requerido
ADMIN.

### Path params
- `workshop_id`: int.

### Request real
Usa `AdminWorkshopUserCreate`.

```json
{
  "full_name": "Mecánico 3",
  "email": "mecanico3@gmail.com",
  "password": "Temporal123",
  "phone": "70000000",
  "role": "technician"
}
```

### Campos requeridos
- `full_name`
- `email`
- `password`
- `role`

### Campos opcionales
- `phone`

### Roles permitidos en validación inicial
- `workshop`
- `technician`

### Comportamiento real
Aunque la validación inicial acepta `workshop` y `technician`, si `role = workshop` el endpoint devuelve error para evitar crear otro owner. En la práctica, para CU29 debe usarse solo `role = technician`.

Crea:
- Un `User` con rol `technician`.
- Un registro `Technician` vinculado al taller.

### Campos que no acepta actualmente
- `name` como campo separado.
- `is_active`.
- `is_available`.

### Response
```json
{
  "user_id": 20,
  "full_name": "Mecánico 3",
  "email": "mecanico3@gmail.com",
  "phone": "70000000",
  "role": "technician",
  "relation": "technician",
  "workshop_id": 1,
  "technician_id": 7,
  "is_active": true,
  "is_available": null,
  "access_code": null
}
```

### Errores posibles
- `403`: usuario no ADMIN.
- `404`: taller no encontrado.
- `400`: correo ya está en uso.
- `400`: no se permite crear otro owner workshop.
- `422`: rol inválido.

### Uso recomendado en CU29
Sí, para crear técnicos con usuario de acceso. Si se quiere crear técnico sin usuario, hace falta otro endpoint o reutilizar un endpoint existente de workshop adaptado a admin.

## 11. Contrato: PUT /admin/technicians/{technician_id}
### Método y ruta
`PUT /admin/technicians/{technician_id}`

### Rol requerido
ADMIN.

### Path params
- `technician_id`: int.

### Request real
Usa `AdminTechnicianUpdate`. Todos los campos son opcionales.

```json
{
  "name": "Mecánico editado",
  "phone": "70000000",
  "is_active": true,
  "is_available": false
}
```

### Campos aceptados
- `name`
- `phone`
- `is_active`
- `is_available`

### Campos que no acepta
- `workshop_id`
- `user_id`
- `access_code`
- `current_latitude`
- `current_longitude`

### Response
Devuelve `TechnicianResponse`.

```json
{
  "name": "Mecánico editado",
  "phone": "70000000",
  "is_available": false,
  "current_latitude": null,
  "current_longitude": null,
  "id": 4,
  "workshop_id": 1,
  "user_id": null,
  "access_code": "ABC123",
  "access_code_expires_at": "2026-05-29T10:30:00",
  "is_active": true,
  "created_at": "2026-05-29T10:30:00",
  "updated_at": "2026-05-29T10:30:00"
}
```

### Reglas
Si `is_active` se manda como `false`, el backend también fuerza `is_available = false`.

### Errores posibles
- `403`: usuario no ADMIN.
- `404`: técnico no encontrado.

### Uso recomendado en CU29
Sí. Usar para editar técnico por `technician_id`.

## 12. Contrato: PATCH /admin/technicians/{technician_id}/status
### Método y ruta
`PATCH /admin/technicians/{technician_id}/status`

### Rol requerido
ADMIN.

### Path params
- `technician_id`: int.

### Request
Usa body JSON.

```json
{
  "is_active": false
}
```

### Response
Devuelve `TechnicianResponse`.

```json
{
  "name": "Mecánico 2",
  "phone": "70000000",
  "is_available": false,
  "current_latitude": null,
  "current_longitude": null,
  "id": 4,
  "workshop_id": 1,
  "user_id": null,
  "access_code": "ABC123",
  "access_code_expires_at": "2026-05-29T10:30:00",
  "is_active": false,
  "created_at": "2026-05-29T10:30:00",
  "updated_at": "2026-05-29T10:30:00"
}
```

### Reglas
Si `is_active = false`, backend también marca `is_available = false`.

### Errores posibles
- `403`: usuario no ADMIN.
- `404`: técnico no encontrado.

### Uso recomendado en CU29
Sí. Usar para activar/desactivar técnicos por `technician_id`.

## 13. Contrato: GET /admin/users?role=workshop
### Método y ruta
`GET /admin/users?role=workshop`

### Rol requerido
ADMIN.

### Query params
- `skip`: int, default `0`.
- `limit`: int, default `100`.
- `role`: enum opcional. Para CU29 usar `workshop`.

### Request
```json
{}
```

### Response
```json
[
  {
    "id": 3,
    "email": "taller@gmail.com",
    "full_name": "Taller Owner",
    "phone": "70000000",
    "role": "workshop",
    "created_at": "2026-05-29T10:30:00",
    "updated_at": "2026-05-29T10:30:00"
  }
]
```

### Campos disponibles
- `id`
- `email`
- `full_name`
- `phone`
- `role`
- `created_at`
- `updated_at`

### Campos que no vienen
- `is_active`: no existe en modelo `User`.
- Indicador de si ya tiene taller: no viene actualmente.

### Uso recomendado en CU29
Sí, para seleccionar `owner_id` al crear taller. Brecha: conviene filtrar o marcar owners que ya tienen taller para evitar errores 409 en frontend.

## 14. Contrato: PATCH /admin/users/{user_id}
### Método y ruta
`PATCH /admin/users/{user_id}`

### Rol requerido
ADMIN.

### Path params
- `user_id`: int.

### Request
Usa `AdminUserUpdate`.

```json
{
  "email": "nuevo@gmail.com",
  "full_name": "Nuevo Nombre",
  "phone": "70000000",
  "role": "workshop"
}
```

### Campos aceptados
- `email`
- `full_name`
- `phone`
- `role`

### Campos que no acepta
- `is_active`: no existe en `User`.
- `password`: no está en `AdminUserUpdate`.

### Response
```json
{
  "message": "Usuario actualizado exitosamente",
  "user": {
    "id": 3,
    "email": "nuevo@gmail.com",
    "full_name": "Nuevo Nombre",
    "phone": "70000000",
    "role": "workshop",
    "created_at": "2026-05-29T10:30:00",
    "updated_at": "2026-05-29T10:30:00"
  }
}
```

### Errores posibles
- `403`: usuario no ADMIN.
- `404`: usuario no encontrado.
- `400`: correo ya está en uso.

### Uso recomendado en CU29
Usar con cautela solo para owner si se decide editar datos de cuenta. No usar para técnicos sin `user_id`.

## 15. Contrato: PATCH /admin/users/{user_id}/status
### Método y ruta
`PATCH /admin/users/{user_id}/status`

### Rol requerido
ADMIN.

### Path params
- `user_id`: int.

### Request
Usa body JSON.

```json
{
  "is_active": false
}
```

### Response
```json
{
  "message": "Estado actualizado correctamente",
  "user_id": 3,
  "is_active": false
}
```

### Comportamiento real
`User` no tiene campo `is_active`.

Si el usuario es `workshop`:
- Busca `Workshop.owner_id == user.id`.
- Cambia `Workshop.is_active`.

Si el usuario es `technician`:
- Busca `Technician.user_id == user.id`.
- Cambia `Technician.is_active`.
- Si desactiva, también pone `Technician.is_available = false`.

### Errores posibles
- `403`: usuario no ADMIN.
- `404`: usuario no encontrado.
- `404`: workshop del usuario no encontrado.
- `404`: registro técnico del usuario no encontrado.
- `400`: rol no permitido para este módulo.

### Uso recomendado en CU29
Usar para owner workshop por `user_id` si se quiere que el botón de estado del owner controle `Workshop.is_active`. Para técnicos, preferir `PATCH /admin/technicians/{technician_id}/status`.

## 16. Campos que necesita Angular
Tabla principal talleres:
- `id`
- `name`
- `owner_id`
- `owner.full_name`
- `owner.email`
- `address`
- `latitude`
- `longitude`
- `commission_percentage`
- `is_active`
- `technician_count` (no viene actualmente)

Detalle taller:
- `id`
- `name`
- `address`
- `latitude`
- `longitude`
- `commission_percentage`
- `is_active`
- `owner_id`
- `owner`

Usuarios/técnicos asociados:
- `relation`
- `user_id`
- `technician_id`
- `full_name`
- `email`
- `phone`
- `role`
- `is_active`
- `is_available`
- `access_code`

Crear taller:
- `owner_id`
- `name`
- `address`
- `latitude`
- `longitude`
- `commission_percentage`
- `is_active`

Editar taller:
- `name`
- `address`
- `latitude`
- `longitude`
- `commission_percentage`
- `is_active`

Crear técnico:
- `full_name`
- `email`
- `password`
- `phone`
- `role = technician`

Editar técnico:
- `name`
- `phone`
- `is_active`
- `is_available`

## 17. Campos que NO debe editar Angular
No editar en CU29:
- `Workshop.owner_id` en edición.
- `Workshop.created_at`.
- `Workshop.updated_at`.
- `Technician.workshop_id`.
- `Technician.user_id`.
- `Technician.access_code`.
- `Technician.access_code_expires_at`.
- `Technician.current_latitude`.
- `Technician.current_longitude`.
- `User.created_at`.
- `User.updated_at`.
- `User.role` para técnicos sin revisar impacto.
- `User.hashed_password` nunca se expone ni edita.

## 18. IDs correctos para acciones
Owner:
- Identificador real: `user_id`.
- Editar cuenta: `PATCH /admin/users/{user_id}`.
- Cambiar estado del taller desde owner: `PATCH /admin/users/{user_id}/status` o preferiblemente `PATCH /admin/workshops/{workshop_id}/activate`.

Técnico:
- Identificador real: `technician_id`.
- Editar técnico: `PUT /admin/technicians/{technician_id}`.
- Activar/desactivar técnico: `PATCH /admin/technicians/{technician_id}/status`.
- No depender de `user_id`, porque puede ser `null`.

Taller:
- Identificador real: `workshop_id`.
- Editar taller: `PUT /admin/workshops/{workshop_id}`.
- Activar/desactivar taller: `PATCH /admin/workshops/{workshop_id}/activate?is_active=false`.

## 19. Ejemplos de flujo completo
Crear taller:
1. Angular llama `GET /admin/users?role=workshop`.
2. Admin selecciona owner.
3. Admin selecciona ubicación con `app-map-picker`.
4. Angular envía `POST /admin/workshops`.
5. Backend valida owner y crea `Workshop`.
6. Angular refresca `GET /admin/workshops`.

Editar taller:
1. Angular carga `GET /admin/workshops/{workshop_id}`.
2. Admin edita nombre, dirección, comisión, estado y ubicación.
3. Angular envía `PUT /admin/workshops/{workshop_id}`.
4. Angular refresca detalle/listado.

Gestionar técnicos:
1. Angular carga `GET /admin/workshops/{workshop_id}/users`.
2. Owner se muestra con `user_id`.
3. Técnico se muestra con `technician_id`.
4. Crear técnico usa `POST /admin/workshops/{workshop_id}/users`.
5. Editar técnico usa `PUT /admin/technicians/{technician_id}`.
6. Activar/desactivar técnico usa `PATCH /admin/technicians/{technician_id}/status`.

## 20. Brechas detectadas antes de Fase 1
- `POST /admin/workshops` necesita schema admin con `owner_id`. Actualmente usa `WorkshopCreate`, que no declara `owner_id`.
- `GET /admin/workshops` no devuelve `technician_count`.
- `GET /admin/users?role=workshop` no indica si un owner ya tiene taller.
- `POST /admin/workshops/{workshop_id}/users` no acepta `is_active` ni `is_available` al crear técnico.
- `POST /admin/workshops/{workshop_id}/users` crea usuario + técnico; no crea técnico sin cuenta.
- `PATCH /admin/users/{user_id}/status` no cambia `User.is_active` porque ese campo no existe.
- Hay textos con mojibake en backend y frontend, aunque no bloquean el contrato JSON.

## 21. Recomendación para Fase 1 backend
Implementar Fase 1 backend limpia antes de rehacer UI:
- Crear `AdminWorkshopCreate` con `owner_id` obligatorio.
- Usar `AdminWorkshopCreate` en `POST /admin/workshops`.
- Confirmar `WorkshopUpdate` sin `owner_id`.
- Evaluar agregar `technician_count` a un response admin específico o crear endpoint de conteo.
- Evaluar endpoint o campo que indique si un usuario workshop ya tiene taller.
- Mantener técnicos por `technician_id`.
- Mantener owner por `user_id`.
- Probar con Swagger/curl cada endpoint antes de tocar Angular.
