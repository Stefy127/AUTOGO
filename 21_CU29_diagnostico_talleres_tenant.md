# 21 - Diagnóstico CU29: Talleres, sucursales y servicios por tenant

## 1. Resumen del caso de uso
CU29 busca gestionar catálogos operativos por tenant para talleres: talleres, sucursales, técnicos, especialidades y servicios ofrecidos. En AUTOGO, el tenant ya existe conceptualmente como `Workshop`.

## 2. Alcance funcional esperado
Para este CU (principalmente web/admin):
- ADMIN: gestionar talleres (tenant), sucursales por taller, técnicos por taller, especialidades y servicios ofrecidos por taller.
- WORKSHOP: mantener el flujo actual de autogestión de su taller/técnicos (sin crecer demasiado si complica).
- CLIENT y TECHNICIAN: fuera de foco para gestión de catálogos.

## 3. Interpretación de tenant en AUTOGO
Interpretación obligatoria validada:
- `tenant = workshop/taller`
- El aislamiento de datos se hace por `workshop_id`.
- `Workshop.owner_id` identifica al dueño/administrador del taller.
- No se debe crear una entidad `Tenant` separada para CU29.
- ADMIN puede gestionar todos los workshops.
- WORKSHOP solo sus recursos propios (cuando aplica).

## 4. Modelos existentes relacionados
### Existe
- `User` (`backend/app/models.py`): incluye `role` (`admin`, `workshop`, `technician`, `client`) y timestamps.
- `Workshop`: `id`, `owner_id`, `name`, `address`, `latitude`, `longitude`, `commission_percentage`, `is_active`, timestamps.
- `Technician`: `id`, `workshop_id`, `user_id`, `name`, `phone`, `is_active`, `is_available`, ubicación, código de acceso, timestamps.
- `WorkshopPaymentQR` (no es CU29, pero pertenece a taller): `workshop_id` único.
- `Incident`, `Offer`, `Payment` ya referencian `workshop_id` o se infieren por incidente.

### No existe (al menos en modelos actuales)
- `Branch` / `WorkshopBranch` / `Sucursal`.
- `Specialty` / `TechnicianSpecialty`.
- `Service` / `WorkshopService` / `OfferedService`.
- Tablas pivote para especialidades o servicios por taller/técnico.

## 5. Endpoints backend existentes
### Talleres
- `POST /workshops` (WORKSHOP): crear su propio taller.
- `GET /workshops/me` (WORKSHOP): ver su taller.
- `PATCH /workshops/me` (WORKSHOP): editar su taller.
- `GET /admin/workshops` (ADMIN): listar talleres.
- `PATCH /admin/workshops/{workshop_id}/activate?is_active=...` (ADMIN): activar/desactivar taller.

### Técnicos
- `POST /technicians` (WORKSHOP): crear técnico para su taller.
- `GET /technicians` (WORKSHOP): listar técnicos de su taller.
- `PUT /technicians/{technician_id}` (WORKSHOP): editar técnico propio.
- `DELETE /technicians/{technician_id}` (WORKSHOP): eliminar técnico propio.
- `POST /technicians/{technician_id}/access-code/regenerate` (WORKSHOP): regenerar código.
- Endpoints legacy en `workshops.py`: `/workshops/me/technicians`, `/workshops/{workshop_id}/technicians`, `/workshops/me/technicians`.

### Sucursales / Especialidades / Servicios ofrecidos
- No se encontraron routers ni endpoints CRUD dedicados.
- No existen `branches.py`, `specialties.py`, `services.py` en `backend/app/routers`.

### JWT, rol y validación tenant
- Endpoints usan `get_current_user` (JWT).
- Validación por rol está implementada en routers (`UserRole.ADMIN`, `UserRole.WORKSHOP`).
- Para workshop, se valida pertenencia por `Workshop.owner_id == current_user.id` y/o `Technician.workshop_id`.

## 6. Brechas backend detectadas
### Ya existe
- Tenant real por `Workshop` + owner (`owner_id`).
- CRUD suficiente para técnicos del propio taller.
- Admin puede listar y activar/desactivar talleres.

### Parcial
- Gestión admin de talleres en backend es limitada (lista + activar/desactivar); no hay `POST/PUT` admin para `Workshop`.
- Duplicidad funcional técnica (`technicians.py` y partes en `workshops.py`) puede generar deuda técnica futura.

### Falta
- Modelos + CRUD de sucursales.
- Modelos + CRUD de especialidades.
- Modelos + CRUD de servicios ofrecidos por taller.
- Endpoints admin para gestionar técnicos por cualquier taller (hoy el scope fuerte está en workshop owner).

### Riesgos
- Sin diseño de relaciones (especialidades/servicios), crecerá inconsistente.
- Si se agrega CRUD admin sin validar `workshop_id`, riesgo de fuga entre tenants.
- Existen textos/encoding mojibake en algunos archivos; no rompe lógica, pero afecta mantenibilidad.

## 7. Estado actual del frontend Angular
### Existe
- Pantalla admin de “Gestión Talleres” (`admin-workshop-management`) pero actualmente gestiona **usuarios con rol workshop** (`/admin/users?role=workshop`), no un CRUD completo de `Workshop`.
- Panel workshop (`workshop-dashboard`) permite gestionar su taller (`/workshops/me`) y técnicos (`/technicians`).
- Servicios ya existentes:
  - `AdminService`: lista/activar talleres, gestión de usuarios.
  - `WorkshopService`: CRUD de taller propio y técnicos propios.

### No existe
- Pantallas admin para sucursales por taller.
- Pantallas admin para especialidades.
- Pantallas admin para servicios ofrecidos por taller.
- Flujo claro de “Gestionar taller X” con submódulos (tabs/secciones) para todos esos catálogos.

## 8. Brechas frontend detectadas
- “Gestión Talleres” no está orientada al modelo `Workshop` completo (se centra en `User workshop`).
- Falta UI admin unificada por taller con subgestión de:
  - sucursales,
  - técnicos,
  - especialidades,
  - servicios ofrecidos.
- No hay formularios/listados para recursos inexistentes en backend (branches/specialties/services).

## 9. Estado actual de Flutter
- Flutter no tiene alcance principal para CU29 (gestión tenant/admin).
- No se identifican módulos móviles para gestionar talleres/sucursales/especialidades/servicios como catálogos administrativos.
- Recomendación: dejar Flutter fuera del CU29 inicial.

## 10. Recursos CRUD requeridos
Para cerrar CU29:
- `Workshop` (tenant): CRUD admin real.
- `Branch` por `workshop_id`.
- `Technician` por `workshop_id` (admin + workshop scope).
- `Specialty` (catálogo global o por tenant, definir).
- `WorkshopService`/`OfferedService` (servicios ofrecidos por taller, ideal con relación a catálogo de servicios).

## 11. Endpoints recomendados
Si se implementa desde módulo admin (recomendado):

Talleres
- `GET /admin/workshops`
- `POST /admin/workshops`
- `PUT /admin/workshops/{id}`
- `PATCH /admin/workshops/{id}/status`

Sucursales
- `GET /admin/workshops/{workshop_id}/branches`
- `POST /admin/workshops/{workshop_id}/branches`
- `PUT /admin/workshops/{workshop_id}/branches/{branch_id}`
- `PATCH /admin/workshops/{workshop_id}/branches/{branch_id}/status`

Técnicos
- `GET /admin/workshops/{workshop_id}/technicians`
- `POST /admin/workshops/{workshop_id}/technicians`
- `PUT /admin/technicians/{id}`
- `PATCH /admin/technicians/{id}/status`

Especialidades
- `GET /admin/specialties`
- `POST /admin/specialties`
- `PUT /admin/specialties/{id}`
- `PATCH /admin/specialties/{id}/status`

Servicios ofrecidos
- `GET /admin/workshops/{workshop_id}/services`
- `POST /admin/workshops/{workshop_id}/services`
- `PUT /admin/workshop-services/{id}`
- `PATCH /admin/workshop-services/{id}/status`

Nota: primero conviene reutilizar rutas existentes donde aplique (workshops/technicians) y añadir solo lo faltante.

## 12. Diseño recomendado de pantalla web
Mejor ajuste al código actual:
- Extender `admin-workshop-management` con enfoque por `Workshop` (no solo `User`).
- Agregar botón “Gestionar” por taller.
- Vista detalle por taller con tabs:
  - Taller (datos generales)
  - Sucursales
  - Técnicos
  - Especialidades
  - Servicios ofrecidos

Alternativa rápida (una sola pantalla con tabs globales) es posible, pero menos clara para aislamiento por `workshop_id`.

## 13. Riesgos y decisiones pendientes
Decisiones críticas antes de implementar:
1. ¿Especialidades serán catálogo global admin o catálogo por taller?
2. ¿Servicios ofrecidos serán catálogo global + pivote por taller, o entidad libre por taller?
3. ¿Sucursales incluirán geolocalización obligatoria (lat/lng) y `is_active`?
4. ¿Admin podrá crear `Workshop` completo o seguirá creando `User workshop` + perfil por separado?
5. ¿Se mantiene duplicidad de endpoints técnicos (`technicians.py` y `workshops.py`) o se consolida mínimamente?

## 14. Criterios de aceptación
- Admin lista talleres.
- Admin crea/edita/desactiva talleres.
- Admin gestiona sucursales por taller.
- Admin gestiona técnicos por taller.
- Admin gestiona especialidades.
- Admin gestiona servicios ofrecidos por taller.
- Todos los recursos quedan aislados por `workshop_id` (tenant=taller).
- Workshop no gestiona recursos de otro workshop.
- Cliente y técnico no acceden a este módulo.
- No se rompen CU22, CU25, CU27.

## 15. Comandos útiles de verificación
```powershell
docker exec autogo_postgres psql -U autogo -d autogo_db -c "\dt"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT * FROM workshops LIMIT 20;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT * FROM technicians LIMIT 20;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, email, role FROM users WHERE role IN ('admin','workshop','technician') LIMIT 20;"
```
Si existen tablas nuevas en implementación (aún no existen hoy):
```powershell
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT * FROM branches LIMIT 20;"
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT * FROM specialties LIMIT 20;"
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT * FROM services LIMIT 20;"
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT * FROM workshop_services LIMIT 20;"
```

## 16. Plan máximo de 2 fases
### Fase 1 (actual)
- Diagnóstico CU29 y cierre de alcance (`21_CU29_diagnostico_talleres_tenant.md`).

### Fase 2 (única implementación)
Implementación completa y acotada:
1. Backend:
- Agregar modelos faltantes (sucursales, especialidades, servicios ofrecidos) con `workshop_id` donde corresponda.
- CRUD admin de talleres + recursos por taller.
- Reglas de autorización por rol/scope.

2. Angular admin:
- Evolucionar “Gestión Talleres” a módulo de administración por taller con tabs (taller/sucursales/técnicos/especialidades/servicios).
- Formularios/listados CRUD básicos, funcionales y consistentes.

3. Cierre:
- Pruebas CRUD + aislamiento tenant por `workshop_id`.
- Documentación final de CU29.
