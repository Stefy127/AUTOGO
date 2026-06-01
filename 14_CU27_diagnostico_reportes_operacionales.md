# 14 - Diagnóstico CU27: Reportes operacionales

## 1. Resumen del caso de uso
CU27 busca habilitar reportes operacionales para `ADMIN`, `WORKSHOP` y `CLIENT`, con filtros por fecha/taller/tipo/estado y exportación `PDF` y `Excel`, sin romper flujos actuales.

Hallazgo clave del estado actual:
- Ya existen piezas parciales de reportes y estadísticas.
- Hoy el alcance más avanzado está en `WORKSHOP` (stats + PDF de emergencias completadas).
- No existe un módulo unificado de reportes operacionales multirol.

## 2. Alcance por rol
`ADMIN`
- Reporte global del sistema.
- Puede filtrar por fecha, taller, tipo, estado y opcionalmente cliente.
- Debe exportar PDF y Excel.

`WORKSHOP`
- Reporte restringido a su taller (`owner_id -> workshop.id`).
- Puede filtrar por fecha, tipo, estado y técnico.
- Debe exportar PDF y Excel.

`CLIENT`
- Reporte restringido a sus incidentes (`incident.user_id == current_user.id`).
- Puede filtrar por fecha, tipo, estado y opcionalmente vehículo.
- Debe exportar PDF y Excel.

`TECHNICIAN`
- No incluido para esta primera versión del CU27.

## 3. Estado actual del backend
Archivos revisados: `backend/app/models.py`, `backend/app/schemas.py`, `backend/app/routers/*`, `backend/main.py`, `backend/requirements.txt`, `backend/migrations/*`.

Hallazgos actuales:
- No existe router dedicado `reports.py`.
- Sí existen endpoints parciales de reporting:
  - `GET /workshops/me/stats`.
  - `GET /workshops/me/reports/incidents/pdf`.
  - `GET /admin/stats`.
  - `GET /admin/payments/commissions`.
- No existe exportación Excel en backend.
- No existe endpoint JSON operacional unificado por rol.

## 4. Modelos disponibles para reportes
`Incident`
- Campos útiles: `id`, `user_id`, `vehicle_id`, `workshop_id`, `technician_id`, `status`, `priority`, `classification`, `payment_method`, `description`, `location_text`, `accepted_at`, `started_at`, `completed_at`, `created_at`, `updated_at`.

`Payment`
- Campos útiles: `incident_id`, `amount`, `payment_method`, `commission_percentage`, `commission_amount`, `workshop_earnings`, `is_paid`, `paid_at`, `reference_number`, `currency`, `stripe_payment_status`, `created_at`.

`Offer`
- Campos útiles: `incident_id`, `workshop_id`, `technician_id`, `amount`, `status`, `created_at`.

`Workshop`
- Campos útiles: `id`, `owner_id`, `name`, `commission_percentage`, `is_active`.

`Technician`
- Campos útiles: `id`, `workshop_id`, `name`, `is_available`, `is_active`.

`Vehicle`
- Campos útiles: `id`, `user_id`, `brand`, `model`, `year`, `plate`.

`User`
- Campos útiles: `id`, `email`, `full_name`, `role`, `created_at`.

`IncidentHistory`
- Campos útiles: `incident_id`, `status`, `changed_by_user_id`, `timestamp`, `notes`.

## 5. Roles, permisos y alcance de datos
Roles existentes en enum: `client`, `workshop`, `technician`, `admin`.

Patrón actual de acceso:
- `CLIENT`: ve sus datos por `user_id`.
- `WORKSHOP`: se resuelve su taller por `Workshop.owner_id == current_user.id`.
- `ADMIN`: alcance global.

Recomendación CU27:
- Mantener un único endpoint de consulta con filtro + guardas por rol.
- Ignorar o forzar filtros no permitidos según rol (por ejemplo `workshop_id` solo editable para admin).

## 6. Filtros requeridos y filtros recomendados
Filtros mínimos CU27:
- `start_date`
- `end_date`
- `workshop_id`
- `incident_type`
- `status`

Mapeo real sugerido para `incident_type`:
- Usar primero `Incident.classification`.
- Fallback a `description` si `classification` está vacío (solo para visualización, no ideal para filtrado exacto).

Filtros recomendados adicionales:
- `technician_id` (taller/admin).
- `client_id` (solo admin).
- `payment_method`.
- `vehicle_id` (cliente/admin).

## 7. Diseño recomendado del reporte JSON
Endpoint base sugerido:
- `POST /reports/operational/query`.

Estructura sugerida:
```json
{
  "role_scope": "admin|workshop|client",
  "applied_filters": {
    "start_date": "2026-05-01",
    "end_date": "2026-05-31",
    "workshop_id": null,
    "incident_type": null,
    "status": null
  },
  "summary": {
    "total_incidents": 0,
    "pending": 0,
    "assigned": 0,
    "in_progress": 0,
    "completed": 0,
    "cancelled": 0,
    "total_amount": 0,
    "total_workshop_earnings": 0
  },
  "items": []
}
```

## 8. Diseño recomendado de exportación PDF y Excel
Estado actual:
- PDF ya existe para taller (`/workshops/me/reports/incidents/pdf`) con `reportlab`.
- Excel no existe.

Propuesta:
- `POST /reports/operational/export/pdf`
- `POST /reports/operational/export/excel`

Formato PDF recomendado:
- Encabezado: rol, fecha generación, filtros aplicados.
- Bloque resumen KPI.
- Tabla detalle de incidentes.

Formato Excel recomendado:
- Hoja `Resumen`.
- Hoja `Detalle`.

Librerías:
- PDF: reutilizar `reportlab` (ya instalada).
- Excel: agregar en fase posterior `openpyxl`.

## 9. Estado actual del frontend web
Estado Angular actual:
- Existe dashboard general y dashboard de taller.
- `WorkshopDashboardComponent` ya permite descargar PDF de historial completado.
- `AdminService` consume `admin/stats` y `admin/payments/commissions`.
- No existe pantalla unificada de “Reportes Operacionales” multirol.
- No existe flujo de descarga Excel.

## 10. Estado actual del frontend móvil
Estado Flutter actual:
- No existe pantalla de reportes operacionales dedicada.
- No se detectó consumo de endpoints de reportes.
- Sí existe `url_launcher`, por lo que abrir links de descarga es viable en una fase móvil.
- No hay módulo actual de exportación PDF/Excel para reportes de negocio.

## 11. Evaluación de reporte por voz
Diagnóstico de viabilidad:
- En Flutter existen dependencias de audio (`record`, `just_audio`) y permisos (`permission_handler`), pero no `speech_to_text`.
- No hay parsing por voz implementado para filtros.

Conclusión:
- Voz es viable como fase opcional posterior.
- Primera versión recomendada: filtros manuales UI.
- Fase opcional: `speech_to_text` + parser básico de comandos (“mayo”, “pdf”, “completadas”), sin IA externa.

## 12. Endpoints propuestos
Consulta unificada:
- `POST /reports/operational/query` (JWT requerido).

Exportación:
- `POST /reports/operational/export/pdf` (JWT requerido).
- `POST /reports/operational/export/excel` (JWT requerido).

Alternativa si se prefiere separación por rol:
- `/reports/admin/operational`
- `/reports/workshop/operational`
- `/reports/client/operational`

Recomendación principal:
- Endpoint común + `role_scope` calculado en backend para reducir duplicación.

## 13. Cambios de backend propuestos
Cambios mínimos sugeridos para CU27:
- Crear `backend/app/routers/reports.py`.
- Crear schemas de request/response para query/export.
- Registrar router en `backend/main.py`.
- Reutilizar joins actuales entre `Incident`, `Payment`, `Workshop`, `Technician`, `Vehicle`, `User`.
- Aplicar control estricto por rol en query base.
- Reutilizar `reportlab` para PDF.
- Incorporar Excel en Fase 2 (`openpyxl`).

Sin cambios de BD en primera instancia:
- El modelo actual ya contiene datos suficientes para el primer reporte operacional.

## 14. Cambios web propuestos
Angular (fase web):
- Nueva vista `Reportes Operacionales` para roles permitidos.
- Filtros dinámicos por rol.
- Tabla de resultados + resumen KPI.
- Botones `Exportar PDF` y `Exportar Excel`.
- Control visual de permisos:
  - Admin: selector de taller y cliente.
  - Taller: sin selector de taller (fijo al propio).
  - Cliente: solo sus propios datos.

## 15. Cambios móvil propuestos
Flutter (fase móvil):
- Nueva pantalla `ReportsScreen` (alcance inicial básico).
- Filtros mínimos por fecha/estado/tipo.
- Consulta endpoint JSON y muestra resumen + listado.
- Exportación inicial sugerida:
  - abrir URL/descarga en navegador del sistema.
- Voz: mantener fuera del MVP inicial.

## 16. Comandos útiles de verificación
```powershell
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, workshop_id, technician_id, status, classification, created_at, completed_at FROM incidents ORDER BY id DESC LIMIT 20;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, incident_id, amount, payment_method, is_paid, commission_amount, workshop_earnings, paid_at FROM payments ORDER BY id DESC LIMIT 20;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, owner_id, name, is_active, commission_percentage FROM workshops ORDER BY id DESC LIMIT 20;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, email, full_name, role, created_at FROM users ORDER BY id DESC LIMIT 30;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, workshop_id, name, is_available, is_active FROM technicians ORDER BY id DESC LIMIT 30;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, brand, model, year, plate FROM vehicles ORDER BY id DESC LIMIT 30;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, incident_id, workshop_id, technician_id, amount, status, created_at FROM offers ORDER BY id DESC LIMIT 30;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT enumlabel FROM pg_enum WHERE enumtypid = 'incidentstatus'::regtype ORDER BY enumsortorder;"

docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT enumlabel FROM pg_enum WHERE enumtypid = 'paymentmethod'::regtype ORDER BY enumsortorder;"
```

## 17. Riesgos y dudas antes de implementar
Dudas críticas:
- ¿PDF/Excel deben generarse siempre en backend o permitir exportación cliente en frontend para casos simples?
- ¿Móvil requiere exportar archivos en esta primera entrega o solo consulta JSON?
- ¿Cliente debe tener ambos formatos (PDF y Excel) o PDF únicamente?
- ¿En reportes de taller mostrar `amount` total o priorizar `workshop_earnings` como métrica principal?
- ¿Campo oficial para “tipo de emergencia”: `classification` o catálogo nuevo?

Riesgos técnicos:
- Riesgo de fuga de datos entre talleres si no se aplica correctamente `workshop.owner_id`.
- Reportes pesados sin paginación/rango de fechas pueden impactar rendimiento.
- Excel introduce dependencia nueva y manejo de binarios/streaming.
- Voz puede elevar complejidad de UX/permisos sin valor inmediato del MVP.

## 18. Criterios de aceptación
- Admin genera reporte global con filtros y recibe resumen + detalle.
- Taller genera reporte solo de su taller.
- Cliente genera reporte solo de sus emergencias.
- Filtros por fecha funcionan correctamente.
- Filtro por taller funciona solo para admin.
- Filtro por tipo funciona con el campo definido para CU27.
- Exportación PDF funcional para los roles habilitados.
- Exportación Excel funcional para los roles habilitados.
- Web consume y exporta sin romper dashboards actuales.
- Móvil consume el reporte según alcance final definido.
- No se rompen flujos de incidentes, ofertas, pagos, CU22 y CU25.

## 19. Plan de implementación por fases
Fase 1
- Backend JSON por rol (`/reports/operational/query`) con filtros y seguridad.

Fase 2
- Exportación backend PDF y Excel usando mismo set de filtros.

Fase 3
- Pantalla Angular de reportes operacionales por rol.

Fase 4
- Pantalla Flutter de reportes (resumen + detalle + export básico).

Fase 5
- Evaluación/implementación opcional de reporte por voz (sin IA externa).

Fase 6
- QA funcional, pruebas de permisos por rol, regresión y documento final CU27.
