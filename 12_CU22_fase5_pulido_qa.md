# 12 - CU22 Fase 5: Pulido UX y QA manual

## 1. Objetivo
Pulir la experiencia de usuario en el flujo de emergencia offline y dejar checklist de validación manual para cierre de CU22, sin cambiar reglas de negocio ya cerradas.

## 2. Archivos modificados
- `movile_front/lib/screens/emergency_offline_screen.dart`
- `12_CU22_fase5_pulido_qa.md` (nuevo)

## 3. Mejoras UX aplicadas
- Estado `pending` ahora muestra aclaración explícita:
  - `Pendiente de sincronización. Esta emergencia aún no fue enviada al sistema.`
- Estado `syncing` mantiene indicador visual y bloqueo de acciones.
- Estado `failed` muestra:
  - título `Error de sincronización`
  - `last_error`
  - `sync_attempts`
  - sugerencias contextuales (correo/placa) cuando aplica.
- Estado `synced` muestra:
  - `backend_incident_id`
  - `synced_at`
  - botón `Limpiar registro local`.
- Eliminación local ahora pide confirmación antes de borrar.
- Edición de emergencia `failed` ahora la retorna a `pending`, limpia `last_error` y conserva `sync_attempts`.

## 4. Estados revisados
- `pending`: pendiente + botones sincronizar/editar/eliminar.
- `syncing`: loader + bloqueo de edición/eliminación y prevención de doble sync.
- `failed`: error + intentos + botón reintentar + editar/eliminar habilitados.
- `synced`: éxito + datos backend + limpiar registro local + volver al login.

## 5. Reglas preservadas
- Se mantiene una sola emergencia offline activa.
- No se generan nuevos `client_offline_id` al reintentar sincronización.
- No se cambia `client_offline_id`, `local_id` ni `created_offline_at` al editar.
- No se cambia endpoint backend ni reglas de idempotencia.
- No se agregó cola de múltiples emergencias.

## 6. Casos de prueba funcionales
1. Guardado offline exitoso:
  - Crear emergencia válida y confirmar estado `pending`.
2. Persistencia local:
  - Recargar app y confirmar que sigue visible.
3. Prevención de duplicados:
  - Intentar crear otra y confirmar bloqueo con mensaje.
4. Edición:
  - Editar emergencia pendiente/fallida y confirmar persistencia.
  - En `failed`, confirmar cambio a `pending` y limpieza de error.
5. Eliminación:
  - Confirmar diálogo, eliminar y crear una nueva.
6. Sincronización exitosa:
  - Confirmar cambio a `synced` y `backend_incident_id`.
7. Sincronización automática:
  - Crear offline y al recuperar red confirmar intento automático.

## 7. Casos de error probados
1. Correo inexistente:
  - Estado `failed` + mensaje claro.
2. Backend apagado:
  - Estado `failed` + mensaje de conexión.
3. Placa en conflicto:
  - Estado `failed` + mensaje de placa.
4. Reintento:
  - Botón `Reintentar sincronización` funciona sin cambiar `client_offline_id`.

## 8. Regresión de flujos existentes
Validación manual esperada:
- Login funcional.
- Registro funcional.
- Botón `Emergencia offline` visible en login.
- `EmergencyFormScreen` online intacta.
- Flujo offline no usa token para guardar local.
- No se carga lista de vehículos desde API en pantalla offline.
- No se llama backend al guardar local; solo al sincronizar.

## 9. Pruebas manuales recomendadas
1. Guardado offline exitoso.
2. Persistencia local tras recarga.
3. Prevención de duplicados locales.
4. Edición con conservación de `client_offline_id`.
5. Eliminación local con confirmación.
6. Sincronización exitosa.
7. Sincronización automática al volver red.
8. Correo inexistente -> `failed`.
9. Backend apagado -> `failed` y luego reintento exitoso.
10. Idempotencia con mismo `client_offline_id`.

Consulta BD sugerida:
```powershell
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, vehicle_id, status, client_offline_id, client_email_offline, sync_source, created_offline_at, synced_at FROM incidents ORDER BY id DESC LIMIT 20;"
```

## 10. Qué no se modificó
- No se ejecutó `flutter analyze`.
- No se tocó backend (salvo uso del endpoint ya existente).
- No se tocó Angular.
- No se tocaron pagos, Stripe, QR, ofertas, talleres ni mecánico.
- No se cambió CU25.
- No se agregó multi-cola.
- No se crearon usuarios invitados.

## 11. Pendientes para resumen final
- Consolidar evidencias de pruebas manuales (capturas/resultado por caso).
- Confirmar checklist de aceptación CU22 end-to-end.
- Redactar resumen final CU22 con alcance, límites y riesgos residuales.
