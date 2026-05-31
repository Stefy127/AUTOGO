# 18 - CU27 Fase 4: Flutter reportes del cliente

## 1. Objetivo
Implementar en Flutter móvil una pantalla de reportes operacionales para rol cliente, consumiendo endpoints backend ya existentes para consulta JSON y exportación PDF/Excel.

## 2. Alcance móvil
- Botón `Reportes` en el home del cliente (debajo de `Rentar Auto`).
- Pantalla `Mis Reportes` con filtros básicos de cliente.
- Consulta de reporte JSON.
- Visualización de KPIs y listado de incidentes.
- Exportación PDF y Excel usando `POST` con JWT.
- Placeholder visual para voz (sin implementar funcionalidad de voz aún).

## 3. Archivos modificados
- `movile_front/lib/screens/home_screen.dart`
- `movile_front/lib/main.dart`
- `movile_front/lib/screens/client_reports_screen.dart` (nuevo)
- `movile_front/lib/services/reports_service.dart` (nuevo)
- `movile_front/lib/models/report_models.dart` (nuevo)
- `movile_front/lib/services/file_download_helper.dart` (nuevo)
- `movile_front/lib/services/file_download_helper_stub.dart` (nuevo)
- `movile_front/lib/services/file_download_helper_web.dart` (nuevo)
- `movile_front/lib/services/file_download_helper_io.dart` (nuevo)

## 4. Botón agregado en home cliente
Se agregó una opción visual `Reportes` en `HomeScreen`, debajo de `Rentar Auto`, reutilizando el mismo estilo de botones secundarios grandes del home.

Navega a:
- `'/client-reports'`

## 5. Pantalla de reportes
Pantalla nueva:
- `ClientReportsScreen`

Incluye:
- Título: `Mis Reportes`
- Subtítulo: `Consulta reportes de tus emergencias y servicios`
- Placeholder visual: `Espacio reservado para búsqueda por voz`
- Filtros cliente
- Acciones: consultar, limpiar filtros, exportar PDF y exportar Excel
- KPIs compactos
- Listado de detalle
- Mensajes de carga, error y vacío

## 6. Servicio de reportes
Servicio nuevo:
- `ReportsService`

Métodos:
- `queryOperationalReport(payload)` -> `POST /reports/operational/query`
- `exportOperationalReportPdf(payload)` -> `POST /reports/operational/export/pdf`
- `exportOperationalReportExcel(payload)` -> `POST /reports/operational/export/excel`

Headers:
- `Authorization: Bearer <token>`
- `Content-Type: application/json`

Notas:
- No envía `client_id`.
- No envía `workshop_id`.
- El scope de cliente lo aplica backend por JWT.

## 7. Filtros disponibles
Se implementaron filtros básicos para cliente:
- `start_date`
- `end_date`
- `incident_type`
- `status`
- `payment_method`

No se muestran:
- `workshop_id`
- `client_id`
- `technician_id`
- filtros de admin/taller

## 8. KPIs mostrados
- Total incidentes
- Pendientes
- En progreso
- Completados
- Cancelados
- Monto total
- Pagos realizados
- Pagos pendientes

Si un valor llega nulo, se muestra `0`.

## 9. Listado de incidentes
Cada ítem muestra:
- ID de emergencia
- Fecha
- Estado
- Tipo/clasificación
- Vehículo
- Taller
- Monto
- Método de pago
- Pagado Sí/No

Si no hay resultados:
- `No hay reportes para los filtros seleccionados`

Si está cargando:
- loader de progreso

## 10. Exportación PDF y Excel
Botones:
- `Exportar PDF`
- `Exportar Excel`

Comportamiento:
- Usa los filtros actuales.
- Ejecuta `POST` con JWT y body JSON.
- Descarga bytes del backend.

Descarga por plataforma:
- Web: descarga mediante `Blob/Anchor`.
- IO (Android/iOS/Desktop): guarda archivo en directorio temporal y muestra ruta guardada.

## 11. Seguridad por rol cliente
- Requiere token JWT de sesión activa.
- No expone filtros de otros roles.
- Si backend responde `401/403`, muestra:
  - `No tienes permisos para consultar estos reportes.`

## 12. Qué no se implementó todavía
- No voz todavía.
- Voz sigue siendo obligatoria para el CU completo.
- La voz se implementará después en web y móvil.
- No reportes admin/taller en Flutter porque admin/taller están en Angular.

## 13. Cómo probar en Flutter
1. Iniciar backend en `localhost:8000`.
2. Ejecutar Flutter Web:
   - `flutter run -d chrome --web-port=4200 --dart-define=API_BASE_URL=http://localhost:8000`
3. Login como cliente.
4. Ver botón `Reportes` debajo de `Rentar Auto`.
5. Entrar a `Mis Reportes`.
6. Consultar sin filtros.
7. Validar KPIs y listado.
8. Filtrar por fecha.
9. Filtrar por estado.
10. Exportar PDF.
11. Exportar Excel.
12. Confirmar que no aparecen filtros admin/taller.
13. Confirmar que no se envía `client_id` ni `workshop_id`.

## 14. Pendientes para Fase 5
- Implementar voz en web y móvil (obligatoria para CU27 completo).
- Definir UX final de micrófono para carga de filtros por voz.
- Validación end-to-end de voz + exportaciones.
