# 11 - CU22 Fase 4: Sincronización offline manual y automática

## 1. Objetivo
Implementar sincronización de la emergencia offline guardada localmente contra `POST /incidents/offline-sync`, con:
- sincronización manual por botón
- sincronización automática al recuperar conexión

## 2. Archivos modificados
- `movile_front/pubspec.yaml`
- `movile_front/lib/screens/emergency_offline_screen.dart`
- `movile_front/lib/services/offline_emergency_sync_service.dart` (nuevo)

## 3. Dependencia de conectividad
- Se agregó `connectivity_plus: ^6.0.5` en `pubspec.yaml`.
- Se usa para:
  - revisar conectividad al abrir pantalla
  - escuchar cambios de red con `onConnectivityChanged`

## 4. Servicio de sincronización
Nuevo servicio:
- `OfflineEmergencySyncService`
- Método principal:
  - `syncOfflineEmergency(OfflineEmergency emergency)`

Retorna `OfflineEmergencySyncResult` con:
- `success`
- `idempotent`
- `backendIncidentId`
- `message`

## 5. Endpoint utilizado
- `POST /incidents/offline-sync`
- Sin token (no se envía JWT en esta fase)

## 6. Payload enviado
Se envían exactamente los campos esperados por backend:
- `client_offline_id`
- `client_email`
- `client_phone`
- `vehicle_brand`
- `vehicle_model`
- `vehicle_year`
- `vehicle_plate`
- `incident_type`
- `description`
- `address`
- `latitude`
- `longitude`
- `created_offline_at`

## 7. Sincronización manual
- Si estado `pending`: botón `Sincronizar ahora`.
- Si estado `failed`: botón `Reintentar sincronización`.
- Al iniciar:
  - cambia a `syncing`
  - bloquea doble sincronización con bandera `_isSyncing`
- Si éxito:
  - cambia a `synced`
  - guarda `backend_incident_id`
  - guarda `synced_at`
  - limpia `last_error`
- Si falla:
  - cambia a `failed`
  - incrementa `sync_attempts`
  - guarda `last_error`

## 8. Sincronización automática al recuperar conexión
- Al abrir `EmergencyOfflineScreen`:
  - si hay emergencia `pending` o `failed` y hay red, intenta sincronizar.
- Se escucha conectividad:
  - cuando vuelve red, intenta sincronizar si estado es `pending` o `failed`.
- Si está `syncing`, no lanza sincronización paralela.
- Si está `synced`, no sincroniza de nuevo.

## 9. Manejo de respuestas exitosas
- `created=true` y/o HTTP 201: éxito.
- `idempotent=true` (ya existía): también éxito.
- Mensajes UI:
  - `Emergencia sincronizada correctamente.`
  - `Emergencia ya había sido sincronizada previamente.`

## 10. Manejo de errores
Mapeo implementado:
- `404`:
  - `El correo ingresado no pertenece a un cliente registrado.`
- `422`:
  - `Los datos ingresados no son válidos o el correo no corresponde a un cliente.`
- `409`:
  - `La placa ingresada ya está registrada por otro usuario.`
- conexión / timeout:
  - `No se pudo conectar con el servidor. Revisa tu conexión e intenta nuevamente.`
- genérico:
  - `No se pudo sincronizar la emergencia. Intenta nuevamente.`

## 11. Cambios en EmergencyOfflineScreen
- Se incorporó:
  - carga de emergencia local y auto-sync en `initState`
  - listener de conectividad
  - estados visuales `pending/syncing/failed/synced`
  - botones de sincronización manual/reintento
  - mensaje de error `last_error`
  - botón `Limpiar registro local` cuando está `synced`
- Si al abrir quedó en `syncing` por cierre inesperado:
  - se mueve a `failed` con mensaje de reintento para evitar bloqueo permanente.

## 12. Estados de sincronización
- `pending`: pendiente de sincronización.
- `syncing`: sincronizando en curso.
- `failed`: error, con `last_error` y `sync_attempts` incrementado.
- `synced`: sincronizada con backend.

## 13. Reglas anti-duplicado preservadas
- Se mantiene una sola emergencia local activa.
- No se regenera `client_offline_id` al reintentar.
- No se cambia `client_offline_id` al editar.
- Reintentos usan el mismo `client_offline_id`, por lo tanto backend puede responder idempotente sin duplicar.

## 14. Qué no se implementó todavía
- No se implementó cola de múltiples emergencias offline.
- No se sincronizan ofertas/pagos/QR/tracking.
- No se modificó flujo online normal `EmergencyFormScreen`.
- No se tocaron pagos, Stripe, talleres, mecánico, ni CU25.

## 15. Cómo probar
1. Ejecutar backend en `localhost:8000`.
2. Ejecutar Flutter Web en `localhost:4200`.
3. Abrir app con conexión.
4. Entrar a `Emergencia offline`.
5. En Chrome DevTools -> Network -> Offline.
6. Crear emergencia offline.
7. Confirmar que queda `pending`.
8. Cambiar DevTools -> Network -> No throttling.
9. Confirmar que intenta sincronizar automáticamente.
10. Confirmar que UI queda en `synced`.
11. Confirmar en BD que se creó una sola emergencia.
12. Reintentar con mismo `client_offline_id` y confirmar que no duplica (idempotente).
13. Probar correo inexistente y confirmar estado `failed`.
14. Probar backend apagado y confirmar error de conexión.
15. Probar botón manual `Reintentar sincronización`.

Comando útil para verificar BD:
```powershell
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, vehicle_id, status, client_offline_id, client_email_offline, sync_source, created_offline_at, synced_at FROM incidents ORDER BY id DESC LIMIT 20;"
```

## 16. Pendientes para Fase 5
- Pulido UX de estados/errores y mensajes contextuales.
- Ajustes finales de experiencia de edición/cancelación en escenarios edge.
- Pruebas de regresión completas con escenarios offline prolongados.
