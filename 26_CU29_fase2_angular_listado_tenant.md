# 26 - CU29 Fase 2: Angular listado de talleres tenant

## 1. Objetivo
Implementar la pantalla principal de administración de talleres usando la nueva lógica tenant del backend, sin modificar backend ni otros flujos. La ruta trabajada es `/admin/gestion-talleres`.

## 2. Ruta implementada
- Ruta Angular: `/admin/gestion-talleres`
- Componente: `AdminWorkshopManagementComponent`
- La navegación al detalle queda preparada con el botón `Gestionar`, apuntando a `/admin/gestion-talleres/:id`.
- El detalle no se implementa en esta fase.

## 3. Endpoints usados
La pantalla usa exclusivamente endpoints tenant bajo `/admin/tenant`:

| Acción | Endpoint |
|---|---|
| Listar talleres | `GET /admin/tenant/workshops` |
| Obtener dueños workshop disponibles | `GET /admin/tenant/workshop-owners` |
| Crear taller | `POST /admin/tenant/workshops` |
| Editar taller | `PUT /admin/tenant/workshops/{workshop_id}` |
| Activar/desactivar taller | `PATCH /admin/tenant/workshops/{workshop_id}/status` |

No se usa `/admin/workshops` ni `/workshops` para esta pantalla.

## 4. Modelos Angular creados
Se agregaron interfaces tenant en `frontend/src/app/models/models.ts`:

- `TenantWorkshop`
- `TenantWorkshopOwnerOption`
- `TenantWorkshopCreateRequest`
- `TenantWorkshopUpdateRequest`
- `TenantWorkshopStatusRequest`

Estos modelos separan la gestión tenant del modelo legacy `Workshop`.

## 5. Métodos AdminService
Se agregaron métodos específicos en `AdminService`:

- `getTenantWorkshops()`
- `getTenantWorkshopById()`
- `getTenantWorkshopOwners()`
- `createTenantWorkshop()`
- `updateTenantWorkshop()`
- `setTenantWorkshopStatus()`

La lógica legacy quedó intacta para no romper pantallas previas.

## 6. Tabla principal
La tabla principal muestra:

- ID
- Taller
- Dueño
- Correo
- Dirección
- Comisión
- Estado
- Técnicos
- Acciones

También incluye filtros por texto y estado. El filtro de texto busca por nombre del taller, dirección, nombre del dueño y correo del dueño.

## 7. Crear taller con mapa
El modal de creación permite:

- Seleccionar un dueño workshop disponible.
- Ingresar nombre del taller.
- Seleccionar ubicación con `app-map-picker`.
- Completar dirección automáticamente desde el mapa.
- Definir comisión.
- Crear el taller como activo o inactivo.

Validaciones principales:

- Debe seleccionarse un dueño workshop disponible.
- El nombre es obligatorio.
- La dirección es obligatoria.
- Latitud y longitud son obligatorias.
- La comisión debe estar entre 0 y 100.

## 8. Editar taller con mapa
El modal de edición permite actualizar:

- Nombre.
- Ubicación y dirección mediante mapa.
- Comisión.
- Estado activo/inactivo.

La edición usa `PUT /admin/tenant/workshops/{workshop_id}`.

## 9. Activar/desactivar taller
Desde la tabla se puede activar o desactivar un taller usando:

`PATCH /admin/tenant/workshops/{workshop_id}/status`

Al desactivar se pide confirmación simple para evitar cambios accidentales.

## 10. Estados visuales
La pantalla contempla:

- Cargando talleres.
- Sin talleres registrados.
- Sin resultados por filtros.
- Mensajes de éxito.
- Mensajes de error.
- Botones deshabilitados durante guardado.

## 11. Qué NO se implementó en esta fase
- No se implementó el detalle del taller.
- No se implementó CRUD de técnicos.
- No se implementó CRUD de usuarios workshop dentro del detalle.
- No se modificó backend.
- No se modificó Flutter.
- No se tocaron pagos, Stripe, QR, reportes, CU22 ni CU25.

## 12. Cómo probar
1. Levantar frontend y backend.
2. Iniciar sesión como admin.
3. Entrar a `/admin/gestion-talleres`.
4. Confirmar que la tabla carga desde `/admin/tenant/workshops`.
5. Probar filtro por texto.
6. Probar filtro por estado.
7. Abrir `Crear taller`.
8. Seleccionar dueño workshop disponible.
9. Seleccionar ubicación en el mapa.
10. Guardar y confirmar que aparece en la tabla.
11. Editar taller y confirmar actualización.
12. Activar/desactivar taller.
13. Usar `Gestionar` y confirmar que navega a `/admin/gestion-talleres/:id`.
