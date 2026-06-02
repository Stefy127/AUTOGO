# 20 - CU27 Resumen final: Reportes operacionales

## 1. Objetivo del caso de uso
Implementar reportes operacionales por rol en AUTOGO, con consulta estructurada, exportación PDF/Excel y soporte de comandos por voz/escrito, manteniendo seguridad por alcance de datos.

## 2. Alcance final implementado
Se implementó:
- Backend de reportes operacionales con filtros.
- Exportación a PDF y Excel.
- Pantalla web Angular para admin y taller.
- Pantalla móvil Flutter para cliente.
- Comando por voz y comando escrito con parser backend.
- Pulido visual web/móvil.

No se implementó:
- Rol technician para reportes.
- IA externa para NLP.
- Cambios de BD para CU27.
- Cambios en pagos/Stripe/QR.

## 3. Roles soportados
- `ADMIN`: alcance global, filtros completos, query/export, voz/comando.
- `WORKSHOP`: alcance restringido a su taller, query/export, voz/comando sin ampliar permisos.
- `CLIENT`: alcance restringido a sus emergencias, pantalla móvil, query/export, voz móvil.

## 4. Flujo funcional general
1. Usuario autenticado ingresa a reportes según su rol.
2. Define filtros (fecha, estado, tipo, método y/o IDs permitidos).
3. Consulta reporte JSON o exporta PDF/Excel.
4. Opcionalmente usa voz/comando escrito para autocompletar filtros y ejecutar acción.
5. Backend aplica scope real por rol y devuelve solo datos autorizados.

## 5. Backend implementado
- Módulo de reportes operacionales con lógica unificada de filtros, permisos y armado de respuesta.
- Reutilización de la misma lógica base para query JSON y exportaciones.
- Parser de voz sin IA externa con salida estructurada (`filters`, `action`, `warnings`).

## 6. Endpoints finales
- `POST /reports/operational/query`
- `POST /reports/operational/export/pdf`
- `POST /reports/operational/export/excel`
- `POST /reports/operational/voice-parse`

## 7. Reporte JSON por rol
La respuesta incluye:
- `role_scope`
- `applied_filters`
- `summary`
- `items`

Scope efectivo:
- Admin: sin restricción global.
- Taller: solo `Incident.workshop_id` del taller del usuario.
- Cliente: solo `Incident.user_id` del cliente autenticado.

## 8. Exportación PDF y Excel
- PDF: resumen + detalle de incidentes filtrados.
- Excel: hojas de resumen y detalle.
- Ambos endpoints reutilizan permisos y filtros del reporte JSON.

## 9. Web Angular admin/taller
- Pantalla de Reportes Operacionales integrada al layout real del panel.
- Filtros por rol, KPIs, tabla de detalle y botones de exportación.
- Voz web con Web Speech API + respaldo por comando escrito.
- Validación de IDs positivos en filtros numéricos.
- Eliminación de método no soportado `card/Tarjeta`.

## 10. Flutter móvil cliente
- Pantalla de reportes para cliente.
- Consulta, exportación PDF/Excel y voz móvil.
- Filtros acordes al alcance de cliente.
- Ajustes de UX para instrucciones de voz y visualización de resultados.

## 11. Reportes por voz y comando escrito
- Web: voz nativa navegador + fallback de comando escrito.
- Móvil: voz con reconocimiento local del dispositivo.
- Flujo común: frontend envía texto a `voice-parse`, aplica filtros y ejecuta `query/pdf/excel`.

## 12. Parser de comandos
Reconoce expresiones de:
- Fechas: hoy, ayer, este mes, últimos 7/30 días, meses.
- Estado: pending, waiting_offers, assigned, accepted, in_progress, completed, cancelled.
- Método de pago soportado.
- Tipo de emergencia.
- Acción: `query`, `pdf`, `excel`.
- IDs por rol: cliente/taller/técnico/vehículo según permisos.

## 13. Seguridad por rol
- Backend es la fuente de verdad de permisos.
- Voz/comando no amplía alcance.
- Query/PDF/Excel aplican exactamente la misma validación de scope.
- Cliente no tiene acceso funcional de reportes en Angular.
- Technician queda fuera del alcance del CU27.

## 14. Filtros disponibles
- `start_date`
- `end_date`
- `workshop_id` (admin)
- `incident_type`
- `status`
- `technician_id` (según rol)
- `client_id` (admin)
- `vehicle_id` (según rol)
- `payment_method`

## 15. KPIs y datos mostrados
Resumen/KPIs:
- Total incidentes
- Pendientes
- Esperando ofertas
- Asignados
- Aceptados
- En progreso
- Completados
- Cancelados
- Monto total
- Ganancia taller
- Pagos realizados
- Pagos pendientes

Detalle:
- Identificadores, fechas, estado, clasificación, cliente, vehículo, taller, técnico y datos de pago.

## 16. Pulido visual aplicado
Web:
- Orden final: filtros → voz → KPIs → tabla.
- Cards con diseño limpio/profesional, tabla mejorada, badges visuales.

Móvil:
- Cards de filtros/voz mejoradas.
- KPIs en grid de 2 columnas.
- Mejor legibilidad general de resultados.

## 17. Archivos principales modificados
Backend:
- `backend/app/routers/reports.py`
- `backend/app/schemas.py`
- `backend/main.py`
- `backend/requirements.txt`

Angular:
- `frontend/src/app/components/operational-reports/operational-reports.component.ts`
- `frontend/src/app/components/operational-reports/operational-reports.component.html`
- `frontend/src/app/components/operational-reports/operational-reports.component.css`
- `frontend/src/app/services/reports.service.ts`
- `frontend/src/app/models/models.ts`
- `frontend/src/app/app-routing.module.ts`
- `frontend/src/app/app.module.ts`
- Sidebars/layout admin/workshop ajustados donde correspondió

Flutter:
- `movile_front/lib/screens/client_reports_screen.dart`
- `movile_front/lib/services/reports_service.dart`
- `movile_front/lib/models/report_models.dart`
- Home cliente con acceso a Reportes
- `movile_front/pubspec.yaml`
- `movile_front/pubspec.lock`

Documentación:
- `14_CU27_diagnostico_reportes_operacionales.md`
- `15_CU27_fase1_backend_reportes_json.md`
- `16_CU27_fase2_export_pdf_excel.md`
- `17_CU27_fase3_web_angular_reportes.md`
- `18_CU27_fase4_flutter_reportes_cliente.md`
- `19_CU27_fase5_voz_web_movil.md`
- `20_CU27_resumen_final_reportes_operacionales.md`

## 18. Pruebas realizadas / checklist QA
- Query como admin.
- Query como taller.
- Query como cliente.
- PDF admin/taller/cliente.
- Excel admin/taller/cliente.
- Filtro por fecha.
- Filtro por estado.
- Filtro por método de pago.
- Filtro por ID (admin).
- Voz/comando en web.
- Voz móvil.
- Permisos por rol.
- Cliente sin acceso Angular.
- Technician fuera de alcance.

## 19. Limitaciones conocidas
- Voz web depende de Web Speech API del navegador y puede presentar `network` intermitente.
- Se mitigó con comando escrito en web.
- Voz móvil depende de claridad de audio, permisos y micrófono.
- El parser de voz es por reglas (sin IA externa).

## 20. Qué no se modificó
- Backend de otros CU fuera de reportes.
- Pagos, Stripe, QR, ofertas, flujo mecánico.
- CU22 y CU25.
- Endpoints no relacionados a reportes.

## 21. Conclusión
CU27 queda implementado end-to-end con reportes operacionales por rol, exportación PDF/Excel, cobertura web/móvil, soporte de voz/comando y controles de seguridad por rol, manteniendo coherencia funcional con la arquitectura existente de AUTOGO.
