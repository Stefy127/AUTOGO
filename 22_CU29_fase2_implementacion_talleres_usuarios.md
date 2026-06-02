# 22 - CU29 Fase 2: Gestión de talleres y usuarios por tenant

## 1. Objetivo
Implementar una gestión admin rápida y acotada para tenant=taller en AUTOGO, con:
- listado de talleres (tenant/workshop),
- detalle de taller,
- gestión de usuarios asociados al taller (owner/technicians),
- creación/edición/activación/desactivación de usuarios desde detalle.

## 2. Alcance implementado
- Ruta principal admin: `/admin/gestion-talleres` mejorada.
- Ruta detalle admin: `/admin/gestion-talleres/:id` nueva.
- Visualización de datos del workshop seleccionado.
- Vista única de detalle (sin tabs) con información + usuarios asociados.
- Creación de talleres desde admin con modal.
- Edición de taller desde listado y desde detalle.
- Crear usuario técnico asociado al workshop desde detalle.
- Editar usuario asociado (si tiene `user_id`).
- Activar/desactivar usuario asociado (workshop/technician).

## 3. Qué queda fuera del alcance
- No sucursales.
- No especialidades.
- No servicios ofrecidos.
- No Flutter.
- No entidad Tenant separada.
- Tenant = Workshop/Taller.

## 4. Backend utilizado/modificado
Se reutilizó backend existente y se agregaron endpoints mínimos en `admin.py` para cubrir el detalle:
- `GET /admin/workshops/{workshop_id}`
- `POST /admin/workshops`
- `PUT /admin/workshops/{workshop_id}`
- `GET /admin/workshops/{workshop_id}/users`
- `POST /admin/workshops/{workshop_id}/users`
- `PATCH /admin/users/{user_id}/status`

Se agregaron schemas de soporte en `schemas.py`:
- `AdminWorkshopUserCreate`
- `AdminUserStatusUpdate`
- `AdminWorkshopUserResponse`

## 5. Endpoints usados o creados
Usados:
- `GET /admin/workshops`
- `PATCH /admin/workshops/{workshop_id}/activate`
- `GET /admin/users?role=workshop`
- `GET /admin/stats`
- `PATCH /admin/users/{user_id}`

Creados (mínimos):
- `GET /admin/workshops/{workshop_id}`
- `POST /admin/workshops`
- `PUT /admin/workshops/{workshop_id}`
- `GET /admin/workshops/{workshop_id}/users`
- `POST /admin/workshops/{workshop_id}/users`
- `PATCH /admin/users/{user_id}/status`

## 6. Frontend Angular implementado
- `admin-workshop-management` refactorizado hacia enfoque workshop/tenant.
- Nuevo componente `admin-workshop-detail` en página única (sin tabs).
- Navegación por ruta detalle desde botón Gestionar.
- Integración en `app-routing.module.ts` y `app.module.ts`.
- Extensión de `admin.service.ts` para endpoints de detalle/usuarios.
- Conteo real de técnicos por taller en el listado principal.

## 7. Ruta principal /admin/gestion-talleres
Incluye:
- Header y subtítulo del módulo.
- Cards resumen:
  - total talleres,
  - activos,
  - inactivos,
  - usuarios workshop,
  - técnicos registrados.
- Filtros por búsqueda (nombre/correo/dueño) y estado.
- Botón `+ Crear taller` con modal.
- Tabla de talleres con acciones `Gestionar`, `Editar` y `Activar/Desactivar`.

## 8. Ruta detalle /admin/gestion-talleres/:id
Incluye:
- Botón volver al listado.
- Botón `Editar taller` con modal.
- Card de información del taller (tenant/workshop).
- Tabla de usuarios asociados al workshop en la misma pantalla.
- Columnas de identificación útiles:
  - `Usuario ID` (`user_id`)
  - `Técnico ID` (`technician_id`)

## 9. Gestión de usuarios por taller
En la sección de usuarios:
- Se muestran:
  - owner del taller (`relation=owner`),
  - técnicos del taller (`relation=technician`).
- Acciones:
  - crear usuario,
  - editar usuario,
  - activar/desactivar usuario.

Creación desde detalle:
- Roles permitidos en backend: `workshop` y `technician`.
- Regla implementada: en esta fase, creación efectiva solo para `technician` para no duplicar owner del workshop.

## 10. Reglas de roles
- Todos los endpoints nuevos de detalle están protegidos para `ADMIN`.
- No se permite crear usuarios `client`/`admin` desde este módulo.
- No se permite crear owner workshop adicional desde detalle.

## 11. Seguridad y tenant workshop_id
- tenant = workshop.
- Recursos del detalle se obtienen por `workshop_id`.
- Técnicos creados desde detalle quedan asociados a `workshop_id`.
- Activación/desactivación:
  - workshop user -> `Workshop.is_active`
  - technician user -> `Technician.is_active`
  - en frontend, acción habilitada solo si existe `user_id` para evitar operaciones ambiguas.

## 12. Validaciones
- Crear/editar taller:
  - nombre obligatorio,
  - dirección obligatoria,
  - comisión entre 0 y 100,
  - latitud entre -90 y 90,
  - longitud entre -180 y 180,
  - `owner_id` obligatorio al crear.
- Validación de workshop existente en endpoints de detalle.
- Validación de rol permitido en creación de usuario.
- Validación de email único al crear usuario.
- Mensajes de error para usuario no encontrado o relación no válida.

## 13. Cómo probar
1. Login como admin.
2. Ir a `/admin/gestion-talleres`.
3. Ver cards resumen y tabla de talleres.
4. Aplicar filtros por nombre/estado.
5. Clic en `Gestionar` de un taller.
6. Ver ruta `/admin/gestion-talleres/{id}`.
7. Revisar tab Información.
8. Ir a tab Usuarios.
9. Crear usuario técnico asociado al taller.
10. Editar usuario asociado (si aplica).
11. Activar/desactivar usuario.
12. Verificar que cliente/técnico no acceden al módulo.
13. Verificar que CU27 reportes sigue operando.

## 14. Limitaciones conocidas
- Técnicos sin `user_id` aparecen como relación técnica, pero no son editables/activables como usuario hasta vincular cuenta.
- No se cambió owner del taller en edición (owner_id se mantiene fijo en esta fase).

## 15. Pendientes no incluidos
- Sucursales por taller.
- Especialidades.
- Servicios ofrecidos por taller.
- Flujo de transferencia de owner workshop entre usuarios.
- Extensión móvil (Flutter) para administración tenant.

## 16. Corrección aplicada (edición/desactivación de técnicos)
- Se corrigió el detalle de taller para que los técnicos se gestionen por `technician_id` (no por `user_id`).
- En frontend:
  - `Editar` para fila `relation=technician` abre edición técnica por `technician_id`.
  - `Activar/Desactivar` para técnico usa `technician_id`.
  - `owner` mantiene flujo por `user_id`.
- Endpoints admin usados/agregados para técnicos:
  - `PUT /admin/technicians/{technician_id}` (editar `name`, `phone`, `is_active`, `is_available`)
  - `PATCH /admin/technicians/{technician_id}/status` (activar/desactivar)
- Se añadió en la tabla soporte visual de `Técnico ID` y acciones habilitadas cuando existe `technician_id`.

## 17. Mejora visual aplicada (modales y tablas)
- Se mejoró visualmente:
  - modal de crear taller,
  - modal de editar taller,
  - modal de crear técnico,
  - modal de editar técnico/usuario.
- Se alineó la tabla de usuarios asociados:
  - columnas ID centradas,
  - badges y chips visuales para estado/rol,
  - acciones en fila y mejor espaciado.
- Se mantuvo fuera de alcance:
  - sucursales,
  - especialidades,
  - servicios ofrecidos,
  - entidad Tenant separada (tenant = workshop).

## 18. Ajuste final urgente (mapa en crear/editar taller)
- Se reutilizó el mismo componente de selección de ubicación del flujo existente de registro/edición de taller:
  - `app-map-picker` (Google Maps Picker).
- En `Crear taller`:
  - se retiraron latitud/longitud como entrada manual principal,
  - la ubicación se selecciona en mapa,
  - se guarda internamente `latitude/longitude` y se envía al backend.
- En `Editar taller` (listado y detalle):
  - se muestra mapa con ubicación actual,
  - se puede seleccionar nueva ubicación,
  - se actualizan `latitude/longitude` al guardar.
- Se añadió resumen visual de coordenadas seleccionadas en los modales.
- Se mejoró tabla principal de talleres:
  - columnas equilibradas,
  - acciones sin recorte,
  - dirección con truncado limpio,
  - contador de técnicos visible,
  - scroll horizontal solo como fallback en móvil.
