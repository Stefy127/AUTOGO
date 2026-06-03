# 28 - CU29 Fase 2.1: Corrección Dashboard/Admin Layout

## 1. Objetivo
Corregir el dashboard/admin shell antes de avanzar al detalle de talleres de CU29, dejando el dashboard admin navegable y el sidebar sin caracteres corruptos.

## 2. Ruta final del dashboard
La ruta real del dashboard admin se mantiene como:

`/dashboard`

No se creó ni se cambió a `/admin/dashboard`, porque el routing actual del proyecto ya registra `DashboardComponent` en `/dashboard`.

## 3. Error detectado
El dashboard y varias pantallas admin tenían iconos y textos con mojibake, por ejemplo:

- `ðŸ...` en iconos.
- `GestiÃ³n` en textos.
- `BitÃ¡cora`.
- `â˜°` en el botón de colapsar sidebar.

Además, el item Dashboard dentro del dashboard no tenía `routerLink`, lo que hacía menos consistente la navegación.

## 4. Qué se corrigió
Se corrigieron los sidebars duplicados del panel admin usando entidades HTML seguras para iconos y textos con tildes.

Pantallas revisadas/corregidas:

- Dashboard admin.
- Gestión Talleres.
- Gestión Clientes.
- Alquiler de Autos.
- Bitácora.

## 5. Archivos tocados
- `frontend/src/app/components/dashboard/dashboard.component.html`
- `frontend/src/app/components/admin-client-management/admin-client-management.component.html`
- `frontend/src/app/components/admin-rental-management/admin-rental-management.component.html`
- `frontend/src/app/components/admin-bitacora/admin-bitacora.component.html`

La pantalla `frontend/src/app/components/admin-workshop-management/admin-workshop-management.component.html` se revisó y ya estaba alineada con el sidebar limpio de la Fase 2.

## 6. Cómo quedó el sidebar
El sidebar admin queda con estos items:

- Dashboard
- Gestión Talleres
- Gestión Clientes
- Alquiler de Autos
- Bitácora
- Reportes Operacionales

Cada pantalla mantiene su item activo correspondiente.

Los iconos usan entidades HTML, por ejemplo:

- `&#128202;` Dashboard
- `&#128295;` Gestión Talleres
- `&#128101;` Gestión Clientes
- `&#128665;` Alquiler de Autos
- `&#129534;` Bitácora
- `&#128200;` Reportes Operacionales

Esto evita que se rendericen como cuadros raros por problemas de encoding.

## 7. Confirmación sobre Gestión Talleres
No se cambió la lógica de `/admin/gestion-talleres`.

Se mantiene:

- Tabla de talleres tenant.
- Filtros.
- Cards KPI.
- Botón `+ Crear taller`.
- Modal de creación con dueño + taller.
- Edición.
- Activar/desactivar.

## 8. Qué no se tocó
- No se tocó backend.
- No se tocó Flutter.
- No se tocaron endpoints `/admin/tenant`.
- No se tocó `/admin/gestion-talleres/:id`.
- No se tocaron CU22, CU25 ni CU27.
- No se tocaron reportes, voz, pagos, Stripe ni QR.
- No se instalaron librerías.

## 9. Cómo probar
1. Ejecutar frontend.
2. Iniciar sesión como admin.
3. Entrar a `/dashboard`.
4. Confirmar que el dashboard carga sin caracteres corruptos.
5. Confirmar que el sidebar muestra iconos correctos.
6. Hacer click en `Gestión Talleres`.
7. Confirmar que `/admin/gestion-talleres` sigue funcionando.
8. Navegar a `Gestión Clientes`, `Alquiler de Autos` y `Bitácora`.
9. Confirmar que el sidebar se ve consistente y marca el item activo.
10. Confirmar que no hay errores en consola.
