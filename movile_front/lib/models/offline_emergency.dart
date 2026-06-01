class OfflineEmergency {
  final String localId;
  final String clientOfflineId;
  final String clientEmail;
  final String? clientPhone;
  final String vehicleBrand;
  final String vehicleModel;
  final int vehicleYear;
  final String vehiclePlate;
  final String incidentType;
  final String description;
  final String address;
  final double? latitude;
  final double? longitude;
  final DateTime createdOfflineAt;
  final String syncStatus;
  final int syncAttempts;
  final String? lastError;
  final int? backendIncidentId;
  final DateTime? syncedAt;

  const OfflineEmergency({
    required this.localId,
    required this.clientOfflineId,
    required this.clientEmail,
    this.clientPhone,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehiclePlate,
    required this.incidentType,
    required this.description,
    required this.address,
    this.latitude,
    this.longitude,
    required this.createdOfflineAt,
    required this.syncStatus,
    required this.syncAttempts,
    this.lastError,
    this.backendIncidentId,
    this.syncedAt,
  });

  OfflineEmergency copyWith({
    String? localId,
    String? clientOfflineId,
    String? clientEmail,
    String? clientPhone,
    String? vehicleBrand,
    String? vehicleModel,
    int? vehicleYear,
    String? vehiclePlate,
    String? incidentType,
    String? description,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? createdOfflineAt,
    String? syncStatus,
    int? syncAttempts,
    String? lastError,
    int? backendIncidentId,
    DateTime? syncedAt,
  }) {
    return OfflineEmergency(
      localId: localId ?? this.localId,
      clientOfflineId: clientOfflineId ?? this.clientOfflineId,
      clientEmail: clientEmail ?? this.clientEmail,
      clientPhone: clientPhone ?? this.clientPhone,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      incidentType: incidentType ?? this.incidentType,
      description: description ?? this.description,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdOfflineAt: createdOfflineAt ?? this.createdOfflineAt,
      syncStatus: syncStatus ?? this.syncStatus,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastError: lastError ?? this.lastError,
      backendIncidentId: backendIncidentId ?? this.backendIncidentId,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'local_id': localId,
      'client_offline_id': clientOfflineId,
      'client_email': clientEmail,
      'client_phone': clientPhone,
      'vehicle_brand': vehicleBrand,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_plate': vehiclePlate,
      'incident_type': incidentType,
      'description': description,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'created_offline_at': createdOfflineAt.toIso8601String(),
      'sync_status': syncStatus,
      'sync_attempts': syncAttempts,
      'last_error': lastError,
      'backend_incident_id': backendIncidentId,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  factory OfflineEmergency.fromJson(Map<String, dynamic> json) {
    return OfflineEmergency(
      localId: json['local_id'] as String,
      clientOfflineId: json['client_offline_id'] as String,
      clientEmail: json['client_email'] as String,
      clientPhone: json['client_phone'] as String?,
      vehicleBrand: json['vehicle_brand'] as String,
      vehicleModel: json['vehicle_model'] as String,
      vehicleYear: (json['vehicle_year'] as num).toInt(),
      vehiclePlate: json['vehicle_plate'] as String,
      incidentType: json['incident_type'] as String,
      description: json['description'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdOfflineAt: DateTime.parse(json['created_offline_at'] as String),
      syncStatus: json['sync_status'] as String,
      syncAttempts: (json['sync_attempts'] as num?)?.toInt() ?? 0,
      lastError: json['last_error'] as String?,
      backendIncidentId: (json['backend_incident_id'] as num?)?.toInt(),
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
    );
  }
}
