import '../models/offline_emergency.dart';
import 'api_service.dart';

class OfflineEmergencySyncResult {
  final bool success;
  final bool idempotent;
  final int? backendIncidentId;
  final String message;

  const OfflineEmergencySyncResult({
    required this.success,
    required this.idempotent,
    this.backendIncidentId,
    required this.message,
  });
}

class OfflineEmergencySyncService {
  final ApiService _apiService = ApiService();

  Future<OfflineEmergencySyncResult> syncOfflineEmergency(
    OfflineEmergency emergency,
  ) async {
    final payload = {
      'client_offline_id': emergency.clientOfflineId,
      'client_email': emergency.clientEmail,
      'client_phone': emergency.clientPhone,
      'vehicle_brand': emergency.vehicleBrand,
      'vehicle_model': emergency.vehicleModel,
      'vehicle_year': emergency.vehicleYear,
      'vehicle_plate': emergency.vehiclePlate,
      'incident_type': emergency.incidentType,
      'description': emergency.description,
      'address': emergency.address,
      'latitude': emergency.latitude,
      'longitude': emergency.longitude,
      'created_offline_at': emergency.createdOfflineAt.toIso8601String(),
    };

    try {
      final response = await _apiService.post('/incidents/offline-sync', payload);
      final incident = response['incident'] as Map<String, dynamic>?;
      final idempotent = response['idempotent'] == true;
      final backendIncidentId =
          (incident != null && incident['id'] is int) ? incident['id'] as int : null;
      final message = (response['message'] ?? '').toString();

      return OfflineEmergencySyncResult(
        success: true,
        idempotent: idempotent,
        backendIncidentId: backendIncidentId,
        message: message.isEmpty
            ? (idempotent
                ? 'Emergencia ya había sido sincronizada previamente.'
                : 'Emergencia sincronizada correctamente.')
            : message,
      );
    } catch (e) {
      final raw = e.toString();

      if (raw.contains('Error: 404')) {
        return const OfflineEmergencySyncResult(
          success: false,
          idempotent: false,
          message: 'El correo ingresado no pertenece a un cliente registrado.',
        );
      }
      if (raw.contains('Error: 422')) {
        return const OfflineEmergencySyncResult(
          success: false,
          idempotent: false,
          message:
              'Los datos ingresados no son válidos o el correo no corresponde a un cliente.',
        );
      }
      if (raw.contains('Error: 409')) {
        return const OfflineEmergencySyncResult(
          success: false,
          idempotent: false,
          message: 'La placa ingresada ya está registrada por otro usuario.',
        );
      }
      if (raw.contains('SocketException') ||
          raw.contains('Failed host lookup') ||
          raw.contains('Connection refused') ||
          raw.contains('TimeoutException')) {
        return const OfflineEmergencySyncResult(
          success: false,
          idempotent: false,
          message:
              'No se pudo conectar con el servidor. Revisa tu conexión e intenta nuevamente.',
        );
      }

      return const OfflineEmergencySyncResult(
        success: false,
        idempotent: false,
        message: 'No se pudo sincronizar la emergencia. Intenta nuevamente.',
      );
    }
  }
}
