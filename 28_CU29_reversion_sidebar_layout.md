# 28 - CU29 Reversión sidebar/admin layout

## 1. Motivo
Después de la corrección anterior del dashboard/admin layout, varias pestañas del panel admin quedaron visualmente afectadas. El problema fue haber normalizado sidebars duplicados en varias pantallas en vez de respetar el layout existente.

Esta reversión devuelve esas pantallas al comportamiento visual anterior y mantiene la pantalla `/admin/gestion-talleres` dentro de su flujo CU29.

## 2. Cambios recientes que rompían el sidebar
Los cambios problemáticos fueron realizados en HTML de pantallas admin existentes:

- `dashboard.component.html`
- `admin-client-management.component.html`
- `admin-rental-management.component.html`
- `admin-bitacora.component.html`

Se habían reemplazado iconos y textos del sidebar por entidades HTML y se había compactado la estructura del menú. Aunque era una corrección de encoding, cambió el visual del sidebar en varias pestañas.

## 3. Qué se revirtió
Se restauraron esos cuatro HTML al estado anterior del repositorio:

- Dashboard
- Gestión Clientes
- Alquiler de Autos
- Bitácora

Con esto se vuelve al sidebar/layout anterior en esas pestañas.

## 4. Archivos restaurados
- `frontend/src/app/components/dashboard/dashboard.component.html`
- `frontend/src/app/components/admin-client-management/admin-client-management.component.html`
- `frontend/src/app/components/admin-rental-management/admin-rental-management.component.html`
- `frontend/src/app/components/admin-bitacora/admin-bitacora.component.html`

## 5. Qué se dejó como estaba
No se modificaron rutas globales ni estructura general del admin.

Se mantiene:

- `/dashboard`
- `/admin/gestion-talleres`
- `/admin/gestion-clientes`
- `/admin/alquiler-autos`
- `/admin/bitacora`
- `/reports/operational`

No se creó layout nuevo.
No se creó componente sidebar nuevo.
No se rediseñó el admin shell.

## 6. Gestión Talleres
No se revirtió la funcionalidad CU29 de `/admin/gestion-talleres`.

Se mantiene:

- Listado tenant.
- Cards resumen.
- Filtros.
- Modal `+ Crear taller`.
- Creación de dueño workshop + taller.
- Mapa `app-map-picker`.
- Edición.
- Activar/desactivar.
- Uso de endpoints `/admin/tenant`.

## 7. Aislamiento de estilos en Gestión Talleres
No se tocaron estilos globales.

La pantalla `admin-workshop-management` usa CSS propio de componente Angular, por lo que sus clases de tabla, filtros, cards y modal quedan encapsuladas a esa pantalla. No se modificó `styles.css`, `app.component.*`, ni se creó un layout global.

## 8. Qué no se tocó
- No se tocó backend.
- No se tocaron endpoints `/admin/tenant`.
- No se tocó Flutter.
- No se tocaron CU22, CU25 ni CU27.
- No se tocaron reportes, voz, pagos, Stripe ni QR.
- No se implementó el detalle `/admin/gestion-talleres/:id`.
- No se instalaron librerías.

## 9. Cómo probar
1. Iniciar sesión como admin.
2. Entrar a `/dashboard`.
3. Confirmar que el sidebar se ve como antes.
4. Entrar a `/admin/gestion-talleres`.
5. Confirmar que el sidebar no rompe el layout.
6. Confirmar que tabla, filtros y `+ Crear taller` siguen funcionando.
7. Entrar a `/admin/gestion-clientes`.
8. Entrar a `/admin/alquiler-autos`.
9. Entrar a `/admin/bitacora`.
10. Entrar a `/reports/operational`.
11. Confirmar que ninguna pantalla queda afectada por estilos de Gestión Talleres.
