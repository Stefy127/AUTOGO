# 16 - CU27 Fase 2: Exportación PDF y Excel

## 1. Objetivo
Agregar exportación de reporte operacional en `PDF` y `Excel` reutilizando la lógica segura por rol ya implementada en Fase 1.

## 2. Archivos modificados
- `backend/app/routers/reports.py`
- `backend/requirements.txt`

## 3. Endpoints implementados
- `POST /reports/operational/export/pdf`
- `POST /reports/operational/export/excel`

Ambos:
- requieren JWT
- reciben `OperationalReportRequest`
- aplican el mismo scope por rol y filtros de Fase 1
- devuelven archivo descargable

## 4. Reutilización de lógica de reportes
Se centralizó la consulta en función interna:
- `_build_operational_report(db, current_user, payload)`

La misma función es usada por:
- `POST /reports/operational/query`
- `POST /reports/operational/export/pdf`
- `POST /reports/operational/export/excel`

Con esto se evita duplicar reglas de permisos y filtros.

## 5. Exportación PDF
Implementación:
- `reportlab` (sin librerías nuevas de PDF)
- título: `Reporte Operacional`
- incluye:
  - rol (`role_scope`)
  - fecha/hora de generación UTC
  - filtros aplicados
  - resumen KPI
  - detalle por incidente

Si no hay resultados:
- genera PDF válido con resumen y mensaje `Sin registros para los filtros seleccionados`.

## 6. Exportación Excel
Implementación:
- `openpyxl`
- archivo `.xlsx` con 2 hojas:
  - `Resumen`
  - `Detalle`

`Resumen` incluye:
- role_scope
- filtros aplicados
- KPIs de resumen

`Detalle` incluye columnas:
- incident_id
- created_at
- status
- classification
- description
- location_text
- client_name
- client_email
- vehicle_brand
- vehicle_model
- vehicle_plate
- workshop_name
- technician_name
- payment_amount
- payment_method
- payment_is_paid
- commission_amount
- workshop_earnings

Si no hay resultados:
- se genera Excel válido con hoja `Detalle` solo con headers.

## 7. Reglas de seguridad preservadas
Se mantiene exactamente el control de Fase 1:
- `admin`: alcance global con filtros permitidos.
- `workshop`: solo su taller (ignora `workshop_id` malicioso para ampliar scope).
- `client`: solo sus incidentes (ignora `client_id`/`workshop_id` malicioso).
- `technician` u otros roles fuera de alcance: `403`.

## 8. Headers y formatos de descarga
PDF:
- `Content-Type: application/pdf`
- `Content-Disposition: attachment; filename="reporte_operacional.pdf"`

Excel:
- `Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
- `Content-Disposition: attachment; filename="reporte_operacional.xlsx"`

## 9. Qué no se implementó todavía
- No Web Angular.
- No Flutter.
- No voz.
- Voz sigue siendo obligatoria para el CU completo, pero se implementará en fase posterior en web y móvil.

## 10. Cómo probar con curl
PDF:
```bash
curl -X POST http://localhost:8000/reports/operational/export/pdf \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -o reporte_operacional.pdf \
  -d '{}'
```

Excel:
```bash
curl -X POST http://localhost:8000/reports/operational/export/excel \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -o reporte_operacional.xlsx \
  -d '{}'
```

Con filtros:
```bash
curl -X POST http://localhost:8000/reports/operational/export/pdf \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -o reporte_filtrado.pdf \
  -d '{
    "start_date": "2026-05-01",
    "end_date": "2026-05-31",
    "status": "completed",
    "incident_type": "battery"
  }'
```

## 11. Verificación de permisos
Pruebas mínimas:
1. Admin exporta global PDF y Excel.
2. Workshop exporta y solo ve su taller.
3. Client exporta y solo ve sus incidentes.
4. Workshop envía `workshop_id` de otro taller y no amplía alcance.
5. Client envía `client_id` de otro cliente y no amplía alcance.
6. Filtros sin resultados generan archivo válido vacío.

Comando BD útil:
```bash
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, workshop_id, technician_id, status, classification, created_at, completed_at FROM incidents ORDER BY id DESC LIMIT 20;"
```

## 12. Pendientes para Fase 3
- Construir pantalla Angular de reportes operacionales consumiendo JSON y exportaciones.
- Mantener los mismos filtros/contrato de backend.
- Definir UX final de reportes por rol en web.
