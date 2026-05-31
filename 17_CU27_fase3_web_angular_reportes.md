# 17 - CU27 Fase 3: Web Angular reportes operacionales

## 1. Objetivo
Implementar en Angular Web una pantalla de Reportes Operacionales para roles `admin` y `workshop`, consumiendo los endpoints backend de consulta y exportación (JSON/PDF/Excel).

## 2. Alcance web
Incluye:
- consulta JSON del reporte operacional
- filtros por rol
- KPIs
- tabla de detalle
- exportación PDF y Excel

No incluye:
- cliente en Angular (cliente queda para Flutter móvil)
- voz (se deja preparada la pantalla con placeholder visual)

## 3. Archivos modificados
- `frontend/src/app/models/models.ts`
- `frontend/src/app/services/reports.service.ts` (nuevo)
- `frontend/src/app/components/operational-reports/operational-reports.component.ts` (nuevo)
- `frontend/src/app/components/operational-reports/operational-reports.component.html` (nuevo)
- `frontend/src/app/components/operational-reports/operational-reports.component.css` (nuevo)
- `frontend/src/app/app-routing.module.ts`
- `frontend/src/app/app.module.ts`
- `frontend/src/app/components/dashboard/dashboard.component.html`
- `frontend/src/app/components/workshop-dashboard/workshop-dashboard.component.html`
- `frontend/src/app/components/workshop-dashboard/workshop-dashboard.component.css`

## 4. Rutas agregadas
- `'/reports/operational'` (protegida por `AuthGuard`)

## 5. Servicio de reportes
Se creó `ReportsService` con métodos:
- `queryOperationalReport(payload)` -> `POST /reports/operational/query`
- `exportOperationalReportPdf(payload)` -> `POST /reports/operational/export/pdf` (blob)
- `exportOperationalReportExcel(payload)` -> `POST /reports/operational/export/excel` (blob)

## 6. Pantalla implementada
Componente:
- `OperationalReportsComponent`

Incluye:
- título y descripción contextual por rol
- placeholder visual para botón de micrófono (fase posterior)
- bloque de filtros
- acciones: `Consultar`, `Limpiar filtros`, `Exportar PDF`, `Exportar Excel`
- tarjetas KPI
- tabla de detalle
- estados visuales: loading, error, vacío

## 7. Filtros disponibles
Comunes:
- `start_date`
- `end_date`
- `incident_type`
- `status`
- `payment_method`
- `technician_id`

Solo admin:
- `workshop_id`
- `client_id`

Solo taller:
- no muestra `workshop_id`
- no muestra `client_id`

## 8. KPIs mostrados
- Total incidentes
- Pendientes
- Asignados
- En progreso
- Completados
- Cancelados
- Monto total
- Ganancia taller
- Pagos realizados
- Pagos pendientes

Si no hay datos, los KPIs muestran `0`.

## 9. Tabla de detalle
Columnas:
- ID
- Fecha
- Estado
- Tipo
- Cliente
- Vehículo
- Taller
- Técnico
- Monto
- Método pago
- Pagado

Mensajes UX:
- Cargando: `Cargando reportes...`
- Sin resultados: `No hay reportes para los filtros seleccionados`
- Error: mensaje claro desde backend/fallback.

## 10. Exportación PDF y Excel
La pantalla usa los filtros actuales para llamar exportaciones en backend y descargar:
- `reporte_operacional.pdf`
- `reporte_operacional.xlsx`

No requiere consulta previa para exportar.

## 11. Control visual por rol
- Se agregó acceso en navegación para admin y workshop.
- No se agrega acceso para client ni technician.
- El componente redirige a `/dashboard` si entra un rol distinto de `admin/workshop`.
- La seguridad real sigue en backend.

## 12. Qué no se implementó todavía
- No Flutter.
- No voz todavía.
- Voz sigue siendo obligatoria para el CU completo y se implementará luego en web y móvil.
- No se implementó cliente en Angular porque cliente corresponde a Flutter móvil.

## 13. Cómo probar en Angular
1. Iniciar backend y frontend Angular.
2. Login como admin.
3. Entrar a `Reportes Operacionales` desde menú.
4. Consultar sin filtros.
5. Probar filtros por fecha/estado/taller/técnico/método.
6. Descargar PDF y Excel.
7. Login como workshop.
8. Entrar a `Reportes Operacionales` desde menú del taller.
9. Verificar que no aparecen filtros `workshop_id` ni `client_id`.
10. Consultar/exportar y validar resultados de su scope.
11. Login como client: confirmar que no hay acceso en menú Angular a esta pantalla.

## 14. Pendientes para Fase 4
- Implementar pantalla Flutter móvil de reportes para cliente.
- Definir UX móvil para filtros y exportación.
- Preparar fase de voz obligatoria en frontend web/móvil sin romper base actual.

## Nota de corrección de integración de layout
- Se corrigió la integración visual de `Reportes Operacionales` dentro del panel web.
- El enlace `Reportes Operacionales` ahora queda visible de forma consistente para admin en los sidebars de:
  - Gestión Talleres
  - Gestión Clientes
  - Alquiler de Autos
  - Bitácora
- En workshop también queda visible desde su menú del panel.
- En workshop el sidebar de reportes ahora reutiliza la estructura real del panel (nombre del taller + opciones completas del menú), no un sidebar simplificado.
- Se agregó `Notificaciones` en el sidebar workshop de reportes con badge rojo de no leídas.
- Se ajustaron clases CSS para mantener fondo azul oscuro, opciones transparentes y activo morado, evitando botones/tarjetas blancas en el menú lateral.
- En admin el sidebar de reportes mantiene las mismas opciones visuales del panel admin y marca `Reportes Operacionales` como activo.
- Se corrigieron caracteres corruptos (mojibake) en textos e íconos del módulo de reportes (`Método`, `Técnico`, `Sesión`, emojis del menú), preservando el diseño real del sidebar admin/taller.
- La pantalla `/reports/operational` ya no depende de navegación por botón “Volver” como único flujo.
- Cliente sigue sin acceso funcional desde Angular (sin enlace y con redirección por rol en el componente).
