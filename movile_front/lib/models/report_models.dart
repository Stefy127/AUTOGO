class OperationalReportRequest {
  final String? startDate;
  final String? endDate;
  final String? incidentType;
  final String? status;
  final int? vehicleId;
  final String? paymentMethod;

  OperationalReportRequest({
    this.startDate,
    this.endDate,
    this.incidentType,
    this.status,
    this.vehicleId,
    this.paymentMethod,
  });

  Map<String, dynamic> toJson() {
    return {
      if (startDate != null && startDate!.isNotEmpty) 'start_date': startDate,
      if (endDate != null && endDate!.isNotEmpty) 'end_date': endDate,
      if (incidentType != null && incidentType!.isNotEmpty) 'incident_type': incidentType,
      if (status != null && status!.isNotEmpty) 'status': status,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      if (paymentMethod != null && paymentMethod!.isNotEmpty) 'payment_method': paymentMethod,
    };
  }
}

class OperationalReportSummary {
  final int totalIncidents;
  final int pending;
  final int waitingOffers;
  final int assigned;
  final int accepted;
  final int inProgress;
  final int completed;
  final int cancelled;
  final double totalAmount;
  final double totalWorkshopEarnings;
  final int totalPaid;
  final int totalUnpaid;

  OperationalReportSummary({
    required this.totalIncidents,
    required this.pending,
    required this.waitingOffers,
    required this.assigned,
    required this.accepted,
    required this.inProgress,
    required this.completed,
    required this.cancelled,
    required this.totalAmount,
    required this.totalWorkshopEarnings,
    required this.totalPaid,
    required this.totalUnpaid,
  });

  factory OperationalReportSummary.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    int toInt(dynamic v) => v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

    return OperationalReportSummary(
      totalIncidents: toInt(json['total_incidents']),
      pending: toInt(json['pending']),
      waitingOffers: toInt(json['waiting_offers']),
      assigned: toInt(json['assigned']),
      accepted: toInt(json['accepted']),
      inProgress: toInt(json['in_progress']),
      completed: toInt(json['completed']),
      cancelled: toInt(json['cancelled']),
      totalAmount: toDouble(json['total_amount']),
      totalWorkshopEarnings: toDouble(json['total_workshop_earnings']),
      totalPaid: toInt(json['total_paid']),
      totalUnpaid: toInt(json['total_unpaid']),
    );
  }

  static OperationalReportSummary empty() => OperationalReportSummary(
        totalIncidents: 0,
        pending: 0,
        waitingOffers: 0,
        assigned: 0,
        accepted: 0,
        inProgress: 0,
        completed: 0,
        cancelled: 0,
        totalAmount: 0,
        totalWorkshopEarnings: 0,
        totalPaid: 0,
        totalUnpaid: 0,
      );
}

class OperationalReportItem {
  final int incidentId;
  final DateTime? createdAt;
  final String status;
  final String? classification;
  final String? description;
  final String? locationText;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehiclePlate;
  final String? workshopName;
  final String? technicianName;
  final double paymentAmount;
  final String? paymentMethod;
  final bool paymentIsPaid;

  OperationalReportItem({
    required this.incidentId,
    this.createdAt,
    required this.status,
    this.classification,
    this.description,
    this.locationText,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
    this.workshopName,
    this.technicianName,
    required this.paymentAmount,
    this.paymentMethod,
    required this.paymentIsPaid,
  });

  factory OperationalReportItem.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['created_at']?.toString();
    final createdAt = createdAtRaw == null || createdAtRaw.isEmpty ? null : DateTime.tryParse(createdAtRaw);
    final amount = json['payment_amount'];
    return OperationalReportItem(
      incidentId: (json['incident_id'] as num?)?.toInt() ?? 0,
      createdAt: createdAt,
      status: (json['status'] ?? '').toString(),
      classification: json['classification']?.toString(),
      description: json['description']?.toString(),
      locationText: json['location_text']?.toString(),
      vehicleBrand: json['vehicle_brand']?.toString(),
      vehicleModel: json['vehicle_model']?.toString(),
      vehiclePlate: json['vehicle_plate']?.toString(),
      workshopName: json['workshop_name']?.toString(),
      technicianName: json['technician_name']?.toString(),
      paymentAmount: amount is num ? amount.toDouble() : double.tryParse(amount?.toString() ?? '') ?? 0,
      paymentMethod: json['payment_method']?.toString(),
      paymentIsPaid: json['payment_is_paid'] == true,
    );
  }
}

class OperationalReportResponse {
  final String roleScope;
  final Map<String, dynamic> appliedFilters;
  final OperationalReportSummary summary;
  final List<OperationalReportItem> items;

  OperationalReportResponse({
    required this.roleScope,
    required this.appliedFilters,
    required this.summary,
    required this.items,
  });

  factory OperationalReportResponse.fromJson(Map<String, dynamic> json) {
    final itemsJson = (json['items'] as List?) ?? [];
    return OperationalReportResponse(
      roleScope: (json['role_scope'] ?? '').toString(),
      appliedFilters: (json['applied_filters'] as Map?)?.cast<String, dynamic>() ?? {},
      summary: OperationalReportSummary.fromJson((json['summary'] as Map?)?.cast<String, dynamic>() ?? {}),
      items: itemsJson
          .whereType<Map>()
          .map((e) => OperationalReportItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class VoiceReportParseResponse {
  final String recognizedText;
  final OperationalReportRequest filters;
  final String? action;
  final List<String> warnings;

  VoiceReportParseResponse({
    required this.recognizedText,
    required this.filters,
    required this.action,
    required this.warnings,
  });

  factory VoiceReportParseResponse.fromJson(Map<String, dynamic> json) {
    final filtersJson = (json['filters'] as Map?)?.cast<String, dynamic>() ?? {};
    return VoiceReportParseResponse(
      recognizedText: (json['recognized_text'] ?? '').toString(),
      filters: OperationalReportRequest(
        startDate: filtersJson['start_date']?.toString(),
        endDate: filtersJson['end_date']?.toString(),
        incidentType: filtersJson['incident_type']?.toString(),
        status: filtersJson['status']?.toString(),
        vehicleId: filtersJson['vehicle_id'] is num ? (filtersJson['vehicle_id'] as num).toInt() : int.tryParse(filtersJson['vehicle_id']?.toString() ?? ''),
        paymentMethod: filtersJson['payment_method']?.toString(),
      ),
      action: json['action']?.toString(),
      warnings: ((json['warnings'] as List?) ?? []).map((e) => e.toString()).toList(),
    );
  }
}
