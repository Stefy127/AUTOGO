# 27 - CU29 Ajuste: Crear taller con owner

## 1. Motivo del cambio
La Fase 2 de CU29 inicialmente permitia crear un taller seleccionando un usuario workshop existente como dueno. Ese flujo no era el deseado para administracion tenant.

El flujo correcto es que el administrador cree en una sola operacion:

1. El usuario dueno/admin del taller con rol `workshop`.
2. El taller asociado a ese usuario como `owner_id`.

Esto evita depender de usuarios workshop preexistentes y hace que la creacion del tenant sea completa desde la pantalla `/admin/gestion-talleres`.

## 2. Endpoint nuevo
Se agrego el endpoint:

`POST /admin/tenant/workshops/with-owner`

Caracteristicas:

- Requiere usuario autenticado con rol `admin`.
- No reemplaza ni elimina `POST /admin/tenant/workshops`.
- No toca endpoints legacy.
- Crea `User` con rol `workshop`.
- Crea `Workshop` asociado al nuevo usuario.
- Usa transaccion: si falla la creacion del taller, se revierte la creacion del usuario.
- Devuelve el mismo formato de `TenantWorkshopResponse` usado por el listado.

## 3. JSON request
```json
{
  "owner": {
    "full_name": "Juan Perez",
    "email": "juan.taller@gmail.com",
    "phone": "70000000",
    "password": "Temporal123"
  },
  "workshop": {
    "name": "Taller Nuevo",
    "address": "Av. Ejemplo",
    "latitude": -17.78,
    "longitude": -63.18,
    "commission_percentage": 10,
    "is_active": true
  }
}
```

## 4. JSON response
```json
{
  "id": 10,
  "name": "Taller Nuevo",
  "address": "Av. Ejemplo",
  "latitude": -17.78,
  "longitude": -63.18,
  "commission_percentage": 10.0,
  "is_active": true,
  "owner_id": 25,
  "owner_name": "Juan Perez",
  "owner_email": "juan.taller@gmail.com",
  "owner_phone": "70000000",
  "technician_count": 0,
  "active_technician_count": 0,
  "created_at": "2026-05-29T10:30:00",
  "updated_at": "2026-05-29T10:30:00"
}
```

## 5. Cambios en schemas backend
Se agregaron schemas nuevos:

- `TenantWorkshopOwnerCreate`
- `TenantWorkshopDataCreate`
- `TenantWorkshopWithOwnerCreate`

No se eliminaron schemas existentes.

## 6. Cambios en modal Angular
El modal `Crear taller` ya no pide seleccionar un dueno workshop existente.

Ahora contiene dos bloques:

### A. Datos del dueno
- Nombre completo.
- Correo.
- Telefono.
- Contrasena temporal.

### B. Datos del taller
- Nombre del taller.
- Direccion.
- Comision.
- Estado activo.
- Mapa `app-map-picker`.
- Coordenadas seleccionadas como texto auxiliar.

## 7. Cambios en AdminService
Se agrego el metodo:

`createTenantWorkshopWithOwner(payload)`

Este metodo llama a:

`POST /admin/tenant/workshops/with-owner`

Los metodos anteriores se mantienen:

- `getTenantWorkshopOwners()`
- `createTenantWorkshop()`

pero la pantalla de creacion usa el nuevo metodo con owner incluido.

## 8. Validaciones frontend
El formulario valida:

- Nombre del dueno obligatorio.
- Correo del dueno obligatorio y con formato basico valido.
- Contrasena temporal obligatoria con minimo 6 caracteres.
- Nombre del taller obligatorio.
- Direccion obligatoria.
- Latitud obligatoria.
- Longitud obligatoria.
- Comision entre 0 y 100.

## 9. Errores esperados
- `403`: usuario autenticado no es admin.
- `400`: correo ya existe.
- `422`: faltan datos o comision fuera de rango.

## 10. Como probar
1. Iniciar sesion como admin.
2. Ir a `/admin/gestion-talleres`.
3. Presionar `+ Crear taller`.
4. Confirmar que ya no aparece selector de dueno existente.
5. Completar datos del dueno:
   - nombre
   - correo
   - telefono
   - contrasena temporal
6. Completar datos del taller:
   - nombre
   - comision
   - estado
   - ubicacion en mapa
7. Guardar.
8. Confirmar que se crea `User` con rol `workshop`.
9. Confirmar que se crea `Workshop` asociado al nuevo `owner_id`.
10. Confirmar que la tabla se refresca y muestra `owner_name`, `owner_email` y `technician_count = 0`.
11. Probar crear otro taller con el mismo correo y confirmar error claro.

## 11. Que no se modifico
- No se modifico Flutter.
- No se modificaron endpoints legacy.
- No se elimino `POST /admin/tenant/workshops`.
- No se elimino `GET /admin/tenant/workshop-owners`.
- No se tocaron CU22, CU25 ni CU27.
- No se tocaron reportes, voz, pagos, Stripe ni QR.
- No se creo una entidad Tenant separada.
- No se agregaron sucursales, especialidades ni servicios ofrecidos.
