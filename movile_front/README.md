# AutoGo Mobile

Aplicación móvil Flutter para clientes de AutoGo.

## Instalación

```bash
flutter pub get
```

## Ejecución

```bash
flutter run
```

## Configuración

La app resuelve la URL del API automáticamente según la plataforma:
- Android Emulator: `http://10.0.2.2:8000`
- Chrome / Web local: `http://localhost:8000`
- iOS Simulator: `http://localhost:8000`
- Dispositivo físico: `http://TU_IP_LOCAL:8000`

Si necesitas forzar otra URL, usa `--dart-define=API_BASE_URL=...` al ejecutar Flutter.
