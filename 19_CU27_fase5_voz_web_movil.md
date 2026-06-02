# 19 - CU27 Fase 5: Reportes por voz web y mÃ³vil

## 1. Objetivo
Agregar comandos por voz para reportes operacionales en Angular Web (admin/workshop) y Flutter mÃ³vil (cliente), sin IA externa, reutilizando reportes y exportaciones existentes.

## 2. Alcance de voz
- Captura de voz en frontend.
- EnvÃ­o de texto reconocido a backend.
- Backend interpreta el texto y devuelve filtros + acciÃ³n sugerida (`query`, `pdf`, `excel` o `null`).
- Frontend aplica filtros y ejecuta consulta/exportaciÃ³n segÃºn `action`.

## 3. Archivos modificados
- `backend/app/schemas.py`
- `backend/app/routers/reports.py`
- `frontend/src/app/models/models.ts`
- `frontend/src/app/services/reports.service.ts`
- `frontend/src/app/components/operational-reports/operational-reports.component.ts`
- `frontend/src/app/components/operational-reports/operational-reports.component.html`
- `frontend/src/app/components/operational-reports/operational-reports.component.css`
- `movile_front/pubspec.yaml`
- `movile_front/lib/models/report_models.dart`
- `movile_front/lib/services/reports_service.dart`
- `movile_front/lib/screens/client_reports_screen.dart`

## 4. Endpoint voice-parse
Nuevo endpoint backend:
- `POST /reports/operational/voice-parse`
- JWT requerido
- Roles permitidos: `admin`, `workshop`, `client`
- Otros roles: `403`

Request:
```json
{
  "text": "reporte de mayo completadas en pdf"
}
```

Response:
```json
{
  "recognized_text": "reporte de mayo completadas en pdf",
  "filters": {
    "start_date": "2026-05-01",
    "end_date": "2026-05-31",
    "incident_type": null,
    "status": "completed",
    "payment_method": null
  },
  "action": "pdf",
  "warnings": []
}
```

## 5. Parser de comandos
Implementado por palabras clave y normalizaciÃ³n bÃ¡sica (acentos/minÃºsculas), sin IA externa.

Incluye:
- estado
- mÃ©todo de pago
- acciÃ³n (query/pdf/excel)
- fechas por expresiones simples
- tipo de emergencia por keywords

## 6. Comandos reconocidos
- Estado:
  - pendiente(s), esperando ofertas, asignado(a)s, aceptado(a)s, en progreso, completado(a)s/resuelto(a)s, cancelado(a)s
- MÃ©todo:
  - efectivo, transferencia, qr, tarjeta/card
- AcciÃ³n:
  - pdf, excel; si no menciona formato => query
- Fechas:
  - mes en espaÃ±ol (enero..diciembre)
  - hoy, ayer, este mes, mes actual
  - ultimos 7 dias, ultimos 30 dias
- Tipo:
  - bateria, llanta/pinchazo/neumatico, motor, aceite, choque/accidente

## 7. Voz en Angular Web
- Se agregÃ³ botÃ³n `Usar voz` en reportes operacionales.
- Usa Web Speech API (`SpeechRecognition`/`webkitSpeechRecognition`).
- Estados:
  - Escuchando...
  - Procesando comando...
- Muestra:
  - Ãºltimo comando reconocido
  - warnings del backend
- Flujo:
  1. Captura voz.
  2. Llama `POST /reports/operational/voice-parse`.
  3. Aplica filtros al formulario.
  4. Si `action=query` consulta.
  5. Si `action=pdf` exporta PDF.
  6. Si `action=excel` exporta Excel.

## 8. Voz en Flutter mÃ³vil
- Se agregÃ³ botÃ³n `Usar voz` en `ClientReportsScreen`.
- Se usa `speech_to_text`.
- Estados:
  - Escuchando...
  - Procesando comando...
- Muestra:
  - comando reconocido
  - warnings
- Flujo:
  1. Captura voz.
  2. Llama `POST /reports/operational/voice-parse`.
  3. Aplica filtros.
  4. Ejecuta `query/pdf/excel` segÃºn `action`.

## 9. Seguridad por rol
- Voice-parse requiere JWT.
- No amplÃ­a permisos de datos.
- Backend mantiene validaciÃ³n de scope en query/export.
- No se habilitan `client_id/workshop_id/technician_id` por voz en cliente.

## 10. Limitaciones
- No usa IA externa.
- Parser de frases simples por keywords.
- Si navegador no soporta Web Speech API, se muestra error controlado.
- Permisos de micrÃ³fono dependen de navegador/dispositivo.
- `card` se reconoce como palabra, pero si backend no lo soporta como filtro efectivo, se devuelve warning.

## 11. CÃ³mo probar backend
1. Autenticarse con JWT.
2. Probar:
```bash
curl -X POST http://localhost:8000/reports/operational/voice-parse \
  -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"reporte de mayo completadas en pdf\"}"
```
3. Validar filtros y `action`.
4. Probar tambiÃ©n:
  - `reporte de hoy`
  - `emergencias pendientes`
  - `reporte de pagos en efectivo`
  - `reporte de llantas en excel`
  - `reporte de ultimos 7 dias`

## 12. CÃ³mo probar Angular
1. Login admin o workshop.
2. Ir a `Reportes Operacionales`.
3. Clic en `Usar voz`.
4. Decir: `reporte de mayo completadas`.
5. Ver filtros aplicados y consulta.
6. Decir: `reporte de mayo en pdf`.
7. Ver exportaciÃ³n PDF.

## 13. CÃ³mo probar Flutter
1. Login cliente.
2. Ir a `Home` -> `Reportes`.
3. Clic en `Usar voz`.
4. Decir: `mis emergencias completadas`.
5. Ver filtros aplicados y consulta.
6. Decir: `reporte de mayo en excel`.
7. Ver exportaciÃ³n.

## 14. Pendientes para Fase 6
- Pulido visual UX/UI de voz en web y mÃ³vil.
- MensajerÃ­a mÃ¡s guiada de comandos vÃ¡lidos.
- Ajustes de accesibilidad y feedback visual.

## Nota de correcciÃ³n Angular Web
- Se corrigiÃ³ el estado visual de voz en Angular Web para evitar que quede pegado en `Escuchando...`.
- Se usÃ³ `NgZone` en callbacks de `SpeechRecognition` (`onstart`, `onresult`, `onerror`, `onend`) para asegurar actualizaciÃ³n de UI.
- Se asegurÃ³ apagado de estados en `finally` lÃ³gico del flujo (`query`, `pdf`, `excel` y acciÃ³n nula).
- Se estabilizÃ³ el ciclo de vida de la sesiÃ³n de voz:
  - evita sesiones simultÃ¡neas por doble clic
  - maneja `aborted` como cancelaciÃ³n controlada
  - limpia handlers e instancia de `SpeechRecognition` al finalizar
- Se separÃ³ explÃ­citamente la compatibilidad del navegador (`voiceSupported`) de errores temporales (`network`, `aborted`, `no-speech`), para evitar mensajes falsos de â€œnavegador no soportadoâ€.
- Se agregÃ³ `voiceSessionId` para ignorar callbacks de sesiones viejas y evitar cruces entre eventos.
- Se agregÃ³ timeout de seguridad (12s) para evitar bloqueo del botÃ³n cuando no llega audio.
- En web se mantuvo `Usar voz` (Web Speech API) y se agregÃ³ respaldo por comando escrito (`Aplicar comando`) usando el mismo endpoint `POST /reports/operational/voice-parse`.
- Cuando falla `network` en Web Speech API, se muestra mensaje de reintento o uso de comando escrito, sin deshabilitar permanentemente la voz ni confundirlo con falta de soporte del navegador.
- En mÃ³vil la voz sigue funcionando con `speech_to_text`.

## Nota de corrección parser de IDs por voz
- Se agregó reconocimiento de IDs en comandos de voz/texto para: client_id, workshop_id, technician_id y vehicle_id (ej.: 'cliente 12', 'taller id 3', 'tecnico 8', 'vehiculo id 44').
- Se aplicó restricción por rol en /reports/operational/voice-parse con advertencias explícitas cuando llega un filtro no permitido.
- Admin conserva todos los IDs; Workshop solo puede usar technician_id; Client solo puede usar vehicle_id.
- La seguridad final de alcance sigue validándose también en /reports/operational/query y exportaciones.

## Nota de corrección Angular (mapeo de IDs por voz/comando)
- Se corrigió Angular Web para aplicar los filtros por ID devueltos por /reports/operational/voice-parse.
- Admin ahora aplica client_id, workshop_id, 	echnician_id y ehicle_id desde voz o comando escrito.
- Workshop solo aplica 	echnician_id (los demás IDs no se muestran ni se aplican visualmente).

## Nota de corrección funcional previa a Fase 6
- Angular Web: se protegieron IDs de filtros para aceptar solo enteros positivos (> 0) en UI y al construir/aplicar filtros (`workshop_id`, `client_id`, `technician_id`, `vehicle_id`).
- Angular Web: se eliminó el método de pago no soportado `card/Tarjeta` del selector y mapeos.
- Flutter móvil: se eliminó `card/Tarjeta` del selector/mapeo de método de pago en reportes.
- Flutter móvil: se mejoró el texto de ayuda de voz para indicar hablar claro y cerca del micrófono.
- La lógica principal de voz y reportes no se modificó.
