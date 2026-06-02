# 09 - CU22 Fase 2: Pantalla Flutter Emergencia Offline

## 1. Objetivo
Agregar una pantalla Flutter `EmergencyOfflineScreen` accesible sin login desde `LoginScreen`, con formulario offline completo, validaciones básicas y captura opcional de GPS para latitud/longitud, sin guardar localmente ni sincronizar todavía.

## 2. Archivos modificados
- `movile_front/lib/main.dart`
- `movile_front/lib/screens/login_screen.dart`
- `movile_front/lib/screens/emergency_offline_screen.dart` (nuevo en fase 2, actualizado con botón GPS)

## 3. Ruta agregada
- Ruta nueva: `/emergency-offline`
- Registrada en `main.dart` dentro de `routes`.

## 4. Cambios en LoginScreen
- Se agregó un botón visible:
  - Texto: `Emergencia offline`
  - Ícono: `wifi_off_outlined`
  - Navega a: `/emergency-offline`
- El acceso no requiere autenticación.

## 5. Pantalla EmergencyOfflineScreen
- Pantalla con:
  - AppBar `Emergencia offline`
  - Mensaje informativo de uso sin conexión
  - Advertencia de uso de correo registrado en AUTOGO
  - Formulario completo
  - Botón principal `Guardar emergencia offline`
  - Botón secundario `Volver al login`
  - Botón adicional `Usar mi ubicación actual`

## 6. Campos del formulario
- `client_email` (correo registrado)
- `client_phone` (opcional)
- `vehicle_brand`
- `vehicle_model`
- `vehicle_year`
- `vehicle_plate`
- `incident_type`
- `description`
- `address`
- `latitude` (opcional)
- `longitude` (opcional)

## 7. Validaciones implementadas
- Correo obligatorio.
- Correo con formato básico válido.
- Marca obligatoria.
- Modelo obligatorio.
- Año obligatorio.
- Año numérico.
- Año en rango: `1950` a `año_actual + 1`.
- Placa obligatoria.
- Tipo de emergencia obligatorio.
- Descripción obligatoria.
- Dirección obligatoria.
- Latitud opcional, pero numérica si se llena.
- Longitud opcional, pero numérica si se llena.

## 8. Qué no se implementó todavía
- No guarda en `shared_preferences`.
- No sincroniza con backend.
- No genera `client_offline_id`.
- No evita todavía múltiples emergencias activas.
- No llama a `/incidents/offline-sync`.
- Esto corresponde a Fase 3 y Fase 4.

## 9. Cómo probar visualmente
1. Ejecutar Flutter web.
2. Abrir pantalla de login.
3. Confirmar que aparece el botón `Emergencia offline`.
4. Entrar a la pantalla offline.
5. Confirmar que no pide login.
6. Probar enviar formulario vacío y verificar errores.
7. Probar el botón `Usar mi ubicación actual`.
8. Verificar que, si el navegador permite geolocalización, se llenan `latitude` y `longitude` y aparece `Ubicación capturada correctamente.`
9. Verificar que, si falla o se deniega permiso, aparece `No se pudo obtener la ubicación. Puedes ingresar latitud y longitud manualmente.`
10. Llenar formulario correctamente y presionar `Guardar emergencia offline`.
11. Confirmar que muestra solo mensaje temporal y no llama backend.

## 10. Pendientes para Fase 3
- Guardado local en `shared_preferences`.
- Definir estructura local de emergencia offline.
- Implementar regla de una sola emergencia activa.
- Flujo de edición/eliminación local.
- Preparar datos para sincronización posterior.
- Sincronización automática queda como mejora posterior.

## Notas del ajuste GPS
- Se reutiliza la dependencia existente `geolocator` (no se agregó dependencia nueva).
- No se obtiene dirección automática (sin reverse geocoding).
- La dirección manual sigue siendo obligatoria.
- En móvil el GPS puede funcionar sin internet.
- En Flutter Web depende del navegador/permisos de geolocalización.
- Errores manejados:
  - Servicio de ubicación deshabilitado.
  - Permiso denegado o denegado permanentemente.
  - Fallo general al obtener posición.
