# 10 - CU22 Fase 3: Guardado local de emergencia offline

## 1. Objetivo
Implementar guardado local de una emergencia offline usando `shared_preferences`, permitiendo solo una emergencia activa por dispositivo y habilitando vista, edición y eliminación local.

## 2. Archivos modificados
- `movile_front/lib/screens/emergency_offline_screen.dart`
- `movile_front/lib/models/offline_emergency.dart` (nuevo)
- `movile_front/lib/services/offline_emergency_storage_service.dart` (nuevo)

## 3. Modelo local creado
Se creó `OfflineEmergency` con:
- `local_id`
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
- `sync_status`
- `sync_attempts`
- `last_error`
- `backend_incident_id`
- `synced_at`

Incluye:
- `fromJson`
- `toJson`
- `copyWith`

## 4. Servicio de almacenamiento local
Se creó `OfflineEmergencyStorageService` con:
- `getActiveEmergency()`
- `saveEmergency()`
- `updateEmergency()`
- `deleteEmergency()`
- `hasActiveEmergency()`

## 5. Key usada en shared_preferences
- `offline_emergency_active`

## 6. Regla de una sola emergencia activa
- Estados activos: `pending`, `syncing`, `failed`.
- Si ya existe una emergencia activa, no se crea otra.
- Se muestra mensaje:
  - `Ya tienes una emergencia offline pendiente. Puedes editarla o eliminarla antes de crear otra.`
- Se muestra la emergencia existente para:
  - ver
  - editar
  - eliminar localmente

## 7. Cambios en EmergencyOfflineScreen
- Carga inicial de emergencia local al abrir pantalla.
- Caso sin activa: muestra formulario para crear.
- Caso con activa: muestra tarjeta `Emergencia offline pendiente`.
- Edición:
  - conserva `local_id`
  - conserva `client_offline_id`
  - conserva `created_offline_at`
  - actualiza solo campos editables
- Eliminación local:
  - borra `offline_emergency_active`
  - permite crear una nueva luego
- Mensaje al guardar por primera vez:
  - `Emergencia guardada localmente. Podrás sincronizarla cuando vuelva internet.`

## 8. Estados manejados
- `pending` (usado al crear en esta fase)
- `syncing` (reconocido como activo)
- `failed` (reconocido como activo)
- `synced` (no bloquea creación futura si se limpia)

## 9. Qué no se implementó todavía
- No sincroniza con backend.
- No llama a `/incidents/offline-sync`.
- No detecta conexión automática.
- No marca `syncing`, `failed` ni `synced` desde backend todavía.
- Eso queda para Fase 4.

## 10. Cómo probar
1. Entrar a Login.
2. Abrir `Emergencia offline`.
3. Llenar formulario correctamente.
4. Guardar.
5. Confirmar que aparece como emergencia pendiente.
6. Recargar la página/app.
7. Confirmar que la emergencia sigue guardada.
8. Intentar crear otra y confirmar que no se duplica.
9. Editar la emergencia.
10. Confirmar que conserva el mismo `client_offline_id`.
11. Eliminar emergencia local.
12. Confirmar que permite crear una nueva.

## 11. Pendientes para Fase 4
- Integrar llamado real a `POST /incidents/offline-sync`.
- Manejar transición real de estados (`syncing`, `failed`, `synced`) según respuesta backend.
- Guardar y mostrar `last_error`, `sync_attempts`, `backend_incident_id`, `synced_at` durante sincronización.
- Definir flujo de reintento de sincronización.
