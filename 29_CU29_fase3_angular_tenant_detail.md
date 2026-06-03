# 29 - CU29 Fase 3: Angular detalle tenant

## 1. Objetivo
Implementar la pantalla detalle del tenant/taller en Angular para la ruta `/admin/gestion-talleres/:id`, usando exclusivamente endpoints `/admin/tenant` y sin tocar backend, Flutter ni sidebar/layout global.

## 2. Ruta implementada
- Ruta: `/admin/gestion-talleres/:id`
- Componente: `AdminWorkshopDetailComponent`
- Navegación desde la pantalla principal mediante el botón `Gestionar`.

## 3. Endpoints usados
La pantalla usa solo endpoints tenant:

| Acción | Endpoint |
|---|---|
| Obtener taller | `GET /admin/tenant/workshops/{workshop_id}` |
| Obtener owner + técnicos | `GET /admin/tenant/workshops/{workshop_id}/users` |
| Crear técnico | `POST /admin/tenant/workshops/{workshop_id}/technicians` |
| Editar técnico | `PUT /admin/tenant/technicians/{technician_id}` |
| Activar/desactivar técnico | `PATCH /admin/tenant/technicians/{technician_id}/status` |

No se usan endpoints legacy `/admin/workshops`, `/workshops` ni `/technicians` desde este detalle.

## 4. Modelos Angular
Se agregaron modelos en `models.ts`:

- `TenantWorkshopUserRow`
- `TenantTechnicianCreateRequest`
- `TenantTechnicianUpdateRequest`
- `TenantTechnicianStatusRequest`

## 5. Métodos AdminService
Se agregaron métodos tenant-only:

- `getTenantWorkshopUsers(workshopId)`
- `createTenantTechnician(workshopId, payload)`
- `updateTenantTechnician(technicianId, payload)`
- `setTenantTechnicianStatus(technicianId, isActive)`

También se reutiliza:

- `getTenantWorkshopById(id)`

## 6. Card de información del taller
La pantalla muestra:

- ID del taller.
- Nombre.
- Dirección.
- Coordenadas.
- Comisión.
- Estado.
- Dueño.
- Correo dueño.
- Teléfono dueño.

La edición del taller no se implementó en esta fase porque ya existe en la pantalla principal y duplicarla agregaría complejidad innecesaria.

## 7. Tabla owner/técnicos
La tabla muestra owner y técnicos en una sola pantalla, sin tabs.

Columnas:

- Tipo.
- Usuario ID.
- Técnico ID.
- Nombre.
- Correo.
- Teléfono.
- Rol.
- Estado.
- Disponibilidad.
- Código acceso.
- Acciones.

El owner se muestra como solo lectura.

## 8. Crear técnico
Botón:

`+ Crear técnico`

Campos:

- Nombre completo.
- Correo.
- Teléfono.
- Contraseña temporal.
- Técnico activo.
- Técnico disponible.

Reglas:

- Nombre requerido.
- Email requerido con formato básico.
- Password mínimo 6 caracteres.
- Si `is_active = false`, `is_available` se fuerza a `false`.

## 9. Editar técnico
Solo disponible para filas `row_type = technician`.

Campos editables:

- Nombre completo.
- Teléfono.
- Técnico activo.
- Técnico disponible.

No se edita:

- Email.
- Password.
- `user_id`.
- `technician_id`.
- `workshop_id`.
- `access_code`.

## 10. Activar/desactivar técnico
La acción usa:

`PATCH /admin/tenant/technicians/{technician_id}/status`

Al desactivar, el backend fuerza `is_available = false`. Luego se refresca el detalle y los contadores del taller.

## 11. Reglas de IDs
- Owner usa `user_id` solo para visualización.
- Técnico usa siempre `technician_id` para editar y activar/desactivar.
- Nunca se usa `user_id` para acciones de técnico.
- Owner no se edita ni se desactiva desde este detalle.

## 12. Qué NO se implementó
- No se editó taller desde detalle.
- No se crearon sucursales.
- No se crearon especialidades.
- No se crearon servicios ofrecidos.
- No se creó entidad Tenant separada.
- No se tocaron endpoints legacy.
- No se tocó backend.
- No se tocó Flutter.
- No se tocó sidebar/layout.
- No se tocaron CU22, CU25 ni CU27.
- No se tocaron reportes, voz, pagos, Stripe ni QR.

## 13. Cómo probar
1. Iniciar sesión como admin.
2. Ir a `/admin/gestion-talleres`.
3. Presionar `Gestionar` en un taller.
4. Confirmar navegación a `/admin/gestion-talleres/{id}`.
5. Confirmar que se ve el detalle del taller.
6. Confirmar cards resumen.
7. Confirmar que se ve owner como solo lectura.
8. Confirmar que se ven técnicos.
9. Crear técnico.
10. Confirmar que el técnico aparece en tabla.
11. Confirmar que el conteo de técnicos se actualiza.
12. Editar técnico.
13. Activar/desactivar técnico.
14. Confirmar que las acciones usan `technician_id`.
15. Confirmar que `Volver a talleres` regresa a `/admin/gestion-talleres`.
16. Confirmar que no se rompe la pantalla principal ni el sidebar/layout.
