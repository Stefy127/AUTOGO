# 13 - CU22: Gestión de emergencia offline y sincronización

## 1. Objetivo del caso de uso
CU22 resuelve la necesidad de registrar emergencias cuando el cliente no tiene internet. El caso de uso permite:
- registrar una emergencia sin conexión
- guardarla localmente en el dispositivo
- sincronizarla cuando vuelve la conexión
- evitar duplicados tanto localmente como en backend
- manejar errores de sincronización de forma controlada

## 2. Alcance funcional
Incluye:
- emergencia offline accesible sin login
- validación de cliente registrado por correo al sincronizar
- ingreso de datos de vehículo desde cero
- guardado local en el dispositivo
- una sola emergencia offline activa por dispositivo
- sincronización manual
- sincronización automática al recuperar conexión
- idempotencia backend por `client_offline_id`
- mensajes de error controlados

No incluye:
- creación de usuarios invitados
- creación automática de usuarios
- pagos
- Stripe
- QR
- ofertas offline
- tracking offline
- cola de múltiples emergencias

## 3. Flujo funcional completo
1. Cliente sin internet entra a `Emergencia offline` desde Login.
2. Completa correo y datos de emergencia/vehículo.
3. La app guarda la emergencia localmente.
4. La app impide crear otra emergencia activa en paralelo.
5. Al volver la conexión, la app sincroniza (manual o automática).
6. Backend valida que el correo exista.
7. Backend valida que el usuario sea rol `client`.
8. Backend reutiliza o crea vehículo según reglas de placa.
9. Backend crea el incidente normal.
10. Talleres ven la emergencia recién cuando ya está sincronizada en backend.
11. Si falla sincronización, queda en `failed` y se permite editar/reintentar.

## 4. Flujo técnico completo
Flutter local:
- `EmergencyOfflineScreen` gestiona UI, estados y acciones.
- `OfflineEmergency` modela la entidad local.
- `OfflineEmergencyStorageService` persiste la emergencia local.
- `OfflineEmergencySyncService` arma payload y consume endpoint backend.

Persistencia local:
- `shared_preferences`
- key única: `offline_emergency_active`

Conectividad:
- `connectivity_plus` para detectar recuperación de red en la pantalla offline.

Backend offline-sync:
- endpoint `POST /incidents/offline-sync` (sin JWT).
- valida correo/rol, resuelve vehículo y aplica idempotencia.

Base de datos e idempotencia:
- campos de trazabilidad offline en `incidents`.
- índice único parcial `user_id + client_offline_id` para evitar duplicados.

## 5. Cambios en backend
Archivos modificados en fases backend:
- `backend/app/models.py`
- `backend/app/schemas.py`
- `backend/app/routers/incidents.py`
- `backend/main.py`
- `backend/migrations/2026_05_29_cu22_offline_sync.sql`

Implementación:
- endpoint nuevo `POST /incidents/offline-sync`
- schemas:
  - `OfflineIncidentSyncRequest`
  - `OfflineIncidentSyncResponse`
- trazabilidad offline en `incidents`
- validaciones de usuario por correo y rol
- reglas de vehículo por placa
- idempotencia por `user_id + client_offline_id`

## 6. Cambios en base de datos
Campos agregados en `incidents`:
- `client_offline_id`
- `client_email_offline`
- `created_offline_at`
- `synced_at`
- `sync_source`

Índice único parcial:
- `(user_id, client_offline_id)` cuando `client_offline_id IS NOT NULL`

Por qué evita duplicados:
- si se reintenta sincronizar la misma emergencia con el mismo `client_offline_id`, backend detecta registro previo y devuelve el existente (idempotente), sin insertar otro incidente.

## 7. Cambios en Flutter
Componentes y servicios:
- `EmergencyOfflineScreen`
- `OfflineEmergency` (modelo local)
- `OfflineEmergencyStorageService`
- `OfflineEmergencySyncService`

Tecnologías usadas:
- `shared_preferences` para persistencia local
- `connectivity_plus` para detectar recuperación de red
- `geolocator` para captura de latitud/longitud (GPS)

Estados locales gestionados:
- `pending`
- `syncing`
- `failed`
- `synced`

## 8. Estados de sincronización
`pending`
- Significado: guardada localmente, aún no enviada.
- Acciones: sincronizar ahora, editar, eliminar.
- Comportamiento: no debe existir otra emergencia activa.

`syncing`
- Significado: sincronización en curso.
- Acciones: edición/eliminación bloqueadas temporalmente.
- Comportamiento: evita doble sincronización simultánea.

`failed`
- Significado: intento de sincronización falló.
- Acciones: reintentar, editar, eliminar.
- Comportamiento: conserva emergencia local, incrementa intentos y guarda error.

`synced`
- Significado: sincronizada exitosamente con backend.
- Acciones: limpiar registro local, volver al login.
- Comportamiento: ya no bloquea futuras emergencias después de limpiar.

## 9. Reglas anti-duplicado
Local:
- solo una emergencia offline activa por dispositivo (`pending`, `syncing`, `failed`)
- si se intenta crear otra, se muestra la existente

Backend:
- idempotencia por `user_id + client_offline_id`
- reintentos con el mismo `client_offline_id` no duplican incidente
- respuesta `idempotent=true` se trata como éxito en Flutter

```md
`client_offline_id` no representa el id del cliente en base de datos. Es un identificador generado localmente por Flutter para reconocer una emergencia offline específica durante reintentos de sincronización.

Diferencia de identificadores:
- `user_id`: identifica al cliente real en backend.
- `client_offline_id`: identifica la emergencia offline local.
- `incident.id`: identifica la emergencia real creada en backend.

## 10. Reglas de usuario y vehículo
Usuario:
- el correo debe existir en backend
- el rol debe ser `client`
- no se crean usuarios automáticamente

Vehículo:
- si la placa existe para ese cliente: reutilizar
- si no existe: crear vehículo básico (`brand`, `model`, `year`, `plate`)
- si la placa pertenece a otro usuario: error `409`

## 11. Endpoint implementado
| Endpoint | Método | Autenticación | Propósito |
|---|---|---|---|
| `/incidents/offline-sync` | POST | Sin JWT | Sincronizar emergencia offline |

Body de ejemplo:
```json
{
  "client_offline_id": "offline_1717000000000_123456",
  "client_email": "cliente@correo.com",
  "client_phone": "70000000",
  "vehicle_brand": "Toyota",
  "vehicle_model": "Corolla",
  "vehicle_year": 2015,
  "vehicle_plate": "ABC-123",
  "incident_type": "battery",
  "description": "El auto no enciende",
  "address": "Zona Equipetrol",
  "latitude": -17.78,
  "longitude": -63.18,
  "created_offline_at": "2026-05-29T10:30:00"
}
```

### Respuesta exitosa esperada

```json
{
  "incident": {
    "id": 6,
    "status": "pending"
  },
  "created": true,
  "idempotent": false,
  "message": "Incidente sincronizado correctamente"
}
```
Esta respuesta ocurre cuando la app reintenta sincronizar una emergencia que ya fue creada previamente con el mismo client_offline_id.


## 12. Errores controlados
| Caso | Respuesta esperada | Mensaje UI |
|---|---|---|
| correo no existe | 404 | El correo ingresado no pertenece a un cliente registrado |
| correo no cliente | 422 | Los datos ingresados no son válidos o el correo no corresponde a un cliente |
| placa de otro usuario | 409 | La placa ingresada ya está registrada por otro usuario |
| sin conexión/backend caído | failed local | No se pudo conectar con el servidor |

## 13. Pruebas realizadas / checklist QA
- guardado offline
- persistencia local tras recarga
- prevención de duplicados locales
- edición de emergencia local conservando `client_offline_id`
- eliminación local
- sincronización manual
- sincronización automática al recuperar conexión
- caso correo inexistente
- caso backend apagado
- idempotencia con mismo `client_offline_id`
- verificación en BD de creación sin duplicados

## 14. Comandos útiles de prueba
```bash
flutter run -d chrome --web-port=4200 --dart-define=API_BASE_URL=http://localhost:8000
```

```powershell
docker exec autogo_postgres psql -U autogo -d autogo_db -c "SELECT id, user_id, vehicle_id, status, client_offline_id, client_email_offline, sync_source, created_offline_at, synced_at FROM incidents ORDER BY id DESC LIMIT 20;"
```

```bash
docker compose stop backend
docker compose start backend
```

## 15. Consideraciones y límites
- El endpoint offline-sync es público; a futuro requiere controles antiabuso (rate-limit/captcha).
- El modo offline depende del dispositivo/navegador.
- En Flutter Web, DevTools Offline se usa para simular desconexión.
- GPS puede funcionar sin internet en móvil, pero en web depende del navegador y permisos.
- No hay cola múltiple por decisión explícita: una sola emergencia activa.
- La emergencia local no migra entre dispositivos.
- La lógica de sincronización automática está acotada al contexto de la pantalla offline (no servicio global en background).

## 16. Qué no se modificó
- pagos
- Stripe
- QR
- ofertas
- talleres
- mecánico
- `EmergencyFormScreen` online
- CU25

## 17. Conclusión
CU22 queda implementado end-to-end según alcance definido:
- registra emergencia sin internet
- guarda localmente en dispositivo
- evita duplicados local/backend
- sincroniza manual y automáticamente al recuperar conexión
- maneja errores de sincronización con reintento
- crea emergencia visible para talleres solo cuando se sincroniza en backend
