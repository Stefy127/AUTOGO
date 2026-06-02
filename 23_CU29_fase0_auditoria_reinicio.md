# 23 - CU29 Fase 0: Auditoría y reinicio controlado

## 1. Motivo del reinicio
El CU29 se inició con varios parches funcionales sobre la gestión admin de talleres, pero el resultado quedó desordenado. La pantalla `/admin/gestion-talleres` empezó a mezclar CRUD de talleres, conteo de técnicos, modales, mapa y acciones de estado sin una fase backend estable y sin una UI consolidada.

El reinicio busca evitar seguir corrigiendo sobre una base visual y funcional frágil. En esta fase no se modifica código: se audita qué existe, qué sirve y cómo recomenzar por fases limpias.

## 2. Alcance definitivo del CU29
Incluye:
- `tenant = Workshop/Taller`.
- Admin gestiona talleres desde web.
- Admin crea, edita, activa y desactiva talleres.
- Admin ve dueño y técnicos asociados al taller.
- Admin crea, edita, activa y desactiva técnicos del taller.
- Crear/editar taller debe usar mapa para ubicación.
- Rutas admin limpias:
  - `/admin/gestion-talleres`
  - `/admin/gestion-talleres/:id`

No incluye:
- Entidad `Tenant` separada.
- Sucursales.
- Especialidades.
- Servicios ofrecidos.
- Flutter.
- Cambios en CU22, CU25 o CU27.
- Pagos, Stripe, QR, reportes o voz.

## 3. Estado actual del intento anterior
Archivos modificados o creados por el intento actual:
- `backend/app/routers/admin.py`
- `backend/app/schemas.py`
- `frontend/src/app/app-routing.module.ts`
- `frontend/src/app/app.module.ts`
- `frontend/src/app/components/admin-workshop-management/*`
- `frontend/src/app/components/admin-workshop-detail/*`
- `frontend/src/app/services/admin.service.ts`
- `frontend/src/app/models/models.ts`
- `21_CU29_diagnostico_talleres_tenant.md`
- `22_CU29_fase2_implementacion_talleres_usuarios.md`

No se detectaron migraciones nuevas asociadas al CU29. El modelo base `Workshop` y `Technician` ya existía.

## 4. Partes que se pueden conservar
Backend útil para conservar:
- `GET /admin/workshops`
- `GET /admin/workshops/{workshop_id}`
- `POST /admin/workshops`
- `PUT /admin/workshops/{workshop_id}`
- `PATCH /admin/workshops/{workshop_id}/activate`
- `GET /admin/workshops/{workshop_id}/users`
- `POST /admin/workshops/{workshop_id}/users`
- `PUT /admin/technicians/{technician_id}`
- `PATCH /admin/technicians/{technician_id}/status`

Schemas útiles:
- `AdminWorkshopUserCreate`
- `AdminWorkshopUserResponse`
- `AdminUserStatusUpdate`
- `AdminTechnicianUpdate`
- `AdminTechnicianStatusUpdate`
- `WorkshopCreate`
- `WorkshopUpdate`
- `WorkshopResponse`
- `TechnicianResponse`

Frontend útil para conservar:
- Ruta `/admin/gestion-talleres`.
- Ruta `/admin/gestion-talleres/:id`.
- Registro en `app-routing.module.ts` y `app.module.ts`.
- Métodos de `AdminService` para talleres, usuarios asociados y técnicos.
- Uso de `app-map-picker` como selector de ubicación.
- Modelo `AdminWorkshopUser` con `user_id`, `technician_id`, `relation`, `is_active`, `is_available`.

Documentación útil:
- `21_CU29_diagnostico_talleres_tenant.md` como diagnóstico base.
- `22_CU29_fase2_implementacion_talleres_usuarios.md` como registro de intentos y decisiones, pero no como guía final de implementación.

## 5. Partes que se deben rehacer
Se recomienda rehacer la UI de:
- `/admin/gestion-talleres`.
- `/admin/gestion-talleres/:id`.
- Tabla principal de talleres.
- Modales de crear/editar taller.
- Modales de crear/editar técnico.
- Tabla de usuarios/técnicos asociados.

También conviene rehacer de forma ordenada:
- Validaciones frontend.
- Manejo de mensajes de éxito/error.
- Estados de carga.
- Responsive de tablas.
- Integración del mapa dentro de modales.

## 6. Partes que se deben eliminar o dejar de usar
No conviene seguir usando:
- Tabs en detalle de taller.
- Latitud/longitud como inputs principales.
- Acciones de técnicos basadas solo en `user_id`.
- Estilos improvisados que generan scroll horizontal feo o botones cortados.
- Modales sin labels, sin jerarquía visual y sin grid ordenado.
- Código duplicado de formularios de taller si se puede centralizar en métodos claros del mismo componente.

No se debe borrar código todavía. La limpieza debe hacerse en fases posteriores, con diffs controlados.

## 7. Flujo existente de registro de taller con mapa
Archivo principal:
- `frontend/src/app/components/register/register.component.ts`
- `frontend/src/app/components/register/register.component.html`

Componente de mapa reutilizable:
- `frontend/src/app/components/map-picker/map-picker.component.ts`
- `frontend/src/app/components/map-picker/map-picker.component.html`
- `frontend/src/app/components/map-picker/map-picker.component.css`

Cómo funciona:
- El formulario de registro usa `app-map-picker`.
- `app-map-picker` emite `locationSelected`.
- El evento entrega:
  - `address`
  - `latitude`
  - `longitude`
- `RegisterComponent.onLocationSelected()` hace `patchValue` sobre el formulario:
  - `address`
  - `latitude`
  - `longitude`
- Luego el registro crea usuario workshop y llama a `POST /workshops`.

Campos enviados al backend en registro:
- `name`
- `address`
- `phone`
- `latitude`
- `longitude`

Lógica reutilizable para CU29:
- Usar `app-map-picker`.
- Escuchar `(locationSelected)`.
- Guardar internamente `latitude/longitude`.
- Mostrar dirección readonly o editable de forma controlada.
- Mostrar coordenadas como texto de apoyo, no como inputs principales.

No conviene copiar:
- El flujo de registro de usuario completo.
- El auto-login.
- La llamada a `POST /auth/register`.
- El diseño visual del login si no encaja con el panel admin.

## 8. Endpoints backend disponibles
Talleres admin:

| Método | Ruta | Origen | Estado | Recomendación |
|---|---|---|---|---|
| GET | `/admin/workshops` | Existente/admin | Útil | Conservar |
| GET | `/admin/workshops/{workshop_id}` | Intento CU29 | Útil | Conservar |
| POST | `/admin/workshops` | Intento CU29 | Útil | Revisar validaciones en Fase 1 |
| PUT | `/admin/workshops/{workshop_id}` | Intento CU29 | Útil | Conservar |
| PATCH | `/admin/workshops/{workshop_id}/activate` | Existente/admin | Útil | Conservar |

Técnicos admin:

| Método | Ruta | Origen | Estado | Recomendación |
|---|---|---|---|---|
| GET | `/admin/workshops/{workshop_id}/users` | Intento CU29 | Útil | Conservar |
| POST | `/admin/workshops/{workshop_id}/users` | Intento CU29 | Útil | Revisar si conviene crear usuario + técnico o solo técnico |
| PUT | `/admin/technicians/{technician_id}` | Intento CU29 | Útil | Conservar |
| PATCH | `/admin/technicians/{technician_id}/status` | Intento CU29 | Útil | Conservar |

Usuarios admin:

| Método | Ruta | Origen | Estado | Recomendación |
|---|---|---|---|---|
| GET | `/admin/users?role=workshop` | Existente/admin | Útil | Conservar para owner_id/select |
| PATCH | `/admin/users/{user_id}` | Existente/admin | Útil | Conservar |
| PATCH | `/admin/users/{user_id}/status` | Intento CU29 | Útil con cautela | Revisar alcance |

Talleres workshop existentes:

| Método | Ruta | Origen | Estado | Recomendación |
|---|---|---|---|---|
| POST | `/workshops` | Existente | Solo WORKSHOP | No usar para admin |
| GET | `/workshops/me` | Existente | Solo WORKSHOP | No usar para admin |
| PATCH | `/workshops/me` | Existente | Solo WORKSHOP | No usar para admin |

Técnicos workshop existentes:

| Método | Ruta | Origen | Estado | Recomendación |
|---|---|---|---|---|
| POST | `/technicians` | Existente | Solo WORKSHOP | No usar para admin |
| GET | `/technicians` | Existente | Solo WORKSHOP | No usar para admin |
| PUT | `/technicians/{technician_id}` | Existente | Solo WORKSHOP | No usar para admin |
| DELETE | `/technicians/{technician_id}` | Existente | Hard delete | Evitar en CU29 admin |

## 9. Brechas backend reales
Brechas a resolver o verificar en Fase 1:
- Confirmar que `POST /admin/workshops` use un schema compatible con `owner_id`.
- Confirmar que `WorkshopCreate` realmente incluye `owner_id`; si no lo incluye, crear schema admin separado.
- Validar que un `owner_id` con rol `workshop` no tenga ya un taller.
- Evitar modificar `owner_id` en edición.
- Definir si `POST /admin/workshops/{workshop_id}/users` debe crear usuario `technician` + registro `Technician`, o si se necesita endpoint separado para técnico sin usuario.
- Confirmar que activar/desactivar técnico siempre use `Technician.is_active`, no `User.is_active` cuando no existe `user_id`.
- Corregir textos mojibake en errores si se decide limpiar encoding en backend.

## 10. Estado actual Angular
Rutas actuales:
- `/admin/gestion-talleres`
- `/admin/gestion-talleres/:id`

Archivos actuales:
- `frontend/src/app/components/admin-workshop-management/admin-workshop-management.component.ts`
- `frontend/src/app/components/admin-workshop-management/admin-workshop-management.component.html`
- `frontend/src/app/components/admin-workshop-management/admin-workshop-management.component.css`
- `frontend/src/app/components/admin-workshop-detail/admin-workshop-detail.component.ts`
- `frontend/src/app/components/admin-workshop-detail/admin-workshop-detail.component.html`
- `frontend/src/app/components/admin-workshop-detail/admin-workshop-detail.component.css`

Servicios actuales útiles:
- `AdminService.getAllWorkshops()`
- `AdminService.createWorkshop()`
- `AdminService.updateWorkshop()`
- `AdminService.activateWorkshop()`
- `AdminService.getWorkshopById()`
- `AdminService.getWorkshopUsers()`
- `AdminService.createWorkshopUser()`
- `AdminService.updateTechnician()`
- `AdminService.setTechnicianStatus()`

Problema central:
- La implementación visual y de interacción se hizo por parches, no por una composición clara del panel admin.

## 11. Problemas visuales y funcionales detectados
Problemas funcionales:
- El primer intento dejó acciones que dependían de `user_id` aunque técnicos reales pueden tener solo `technician_id`.
- Crear/editar taller empezó con latitud/longitud como inputs manuales.
- La creación de taller necesita reutilizar mapa de registro y no duplicar lógica visual improvisada.
- El detalle debe mantener técnicos con `technician_id` real y sin tabs.

Problemas visuales:
- Tabla principal con columnas apretadas.
- Acciones cortadas o con scroll horizontal incómodo.
- Modales muy básicos.
- Checkboxes mal alineados.
- Tabla de usuarios asociados desalineada.
- Diseño no suficientemente consistente con dashboard admin.

## 12. Estrategia de limpieza
Conservar:
- Endpoints backend admin útiles.
- Schemas admin útiles si compilan y son coherentes.
- `AdminService` como capa de acceso.
- Rutas Angular definitivas.
- `app-map-picker`.
- Documentos CU29 anteriores como historial.

Reescribir:
- HTML/CSS de `admin-workshop-management`.
- HTML/CSS de `admin-workshop-detail`.
- Formularios y modales de crear/editar taller.
- Formularios y modales de crear/editar técnico.
- Tabla principal y tabla de usuarios asociados.

Revisar con `git diff` antes de tocar:
- `backend/app/routers/admin.py`
- `backend/app/schemas.py`
- `frontend/src/app/app-routing.module.ts`
- `frontend/src/app/app.module.ts`
- `frontend/src/app/models/models.ts`
- `frontend/src/app/services/admin.service.ts`

No conviene hacer un `revert` masivo porque parte del backend y de rutas Angular sí puede servir. La opción más limpia es sobrescribir selectivamente los componentes CU29 con una implementación por fases, manteniendo endpoints útiles.

Riesgo principal:
- El sidebar/admin layout fue tocado por CU27 y CU29. Hay que evitar romper rutas de reportes, dashboard, clientes, alquiler y bitácora.

## 13. Nueva planificación por fases
Fase 1 - Backend limpio mínimo:
- Revisar y estabilizar endpoints admin de `Workshop`.
- Revisar y estabilizar endpoints admin de `Technician`.
- Revisar schemas admin.
- Probar en Swagger/curl.
- No tocar UI.

Fase 2 - Angular listado principal:
- Rehacer `/admin/gestion-talleres`.
- Cards resumen.
- Filtros.
- Tabla profesional.
- Crear taller con `app-map-picker`.
- Editar taller con `app-map-picker`.
- Activar/desactivar taller.
- Navegar a detalle.

Fase 3 - Angular detalle del taller:
- Rehacer `/admin/gestion-talleres/:id`.
- Card información taller.
- Usuarios/técnicos asociados sin tabs.
- Crear técnico.
- Editar técnico.
- Activar/desactivar técnico.
- Usar IDs correctos:
  - owner por `user_id`.
  - técnico por `technician_id`.

Fase 4 - Pulido visual + QA + resumen:
- Modales consistentes.
- Tablas alineadas.
- Responsive.
- Checklist QA.
- Documentación final.

## 14. Riesgos
- `WorkshopCreate` puede no ser el schema ideal para admin si mezcla flujo workshop con flujo admin.
- `POST /admin/workshops/{workshop_id}/users` crea usuario y técnico; puede no cubrir técnicos sin cuenta de usuario.
- `app-map-picker` depende de Google Maps y de que el módulo/API key ya esté correctamente configurado.
- Reescribir UI sin revisar layout admin puede romper sidebar o navegación.
- Cambios en `AdminService` pueden impactar otras pantallas admin si se cambian firmas existentes.
- Mojibake existente en varios textos puede confundirse con bug funcional; conviene tratar encoding en una fase separada si se vuelve crítico.

## 15. Checklist para iniciar Fase 1
- Verificar si el build actual pasa o falla.
- Confirmar con Swagger/curl:
  - `GET /admin/workshops`
  - `POST /admin/workshops`
  - `PUT /admin/workshops/{workshop_id}`
  - `PATCH /admin/workshops/{workshop_id}/activate`
  - `GET /admin/workshops/{workshop_id}/users`
  - `POST /admin/workshops/{workshop_id}/users`
  - `PUT /admin/technicians/{technician_id}`
  - `PATCH /admin/technicians/{technician_id}/status`
- Confirmar schema final para crear taller admin:
  - `owner_id`
  - `name`
  - `address`
  - `latitude`
  - `longitude`
  - `commission_percentage`
  - `is_active`
- Confirmar componente de mapa a reutilizar:
  - `frontend/src/app/components/map-picker/map-picker.component.ts`
- Confirmar rutas definitivas:
  - `/admin/gestion-talleres`
  - `/admin/gestion-talleres/:id`
- Definir si se sobrescribe la UI CU29 actual o si se parchea incrementalmente.
- Mantener fuera de alcance:
  - CU22
  - CU25
  - CU27
  - Flutter
  - pagos
  - Stripe
  - QR
  - reportes
  - voz
