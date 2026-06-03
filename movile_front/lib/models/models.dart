class User {
  final int id;
  final String email;
  final String fullName;
  final String? phone;
  final String role;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      phone: json['phone'],
      role: json['role'],
    );
  }
}

class Vehicle {
  final int? id;
  final String brand;
  final String model;
  final int year;
  final String plate;
  final String? color;

  Vehicle({
    this.id,
    required this.brand,
    required this.model,
    required this.year,
    required this.plate,
    this.color,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'],
      brand: json['brand'],
      model: json['model'],
      year: json['year'],
      plate: json['plate'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
      'plate': plate,
      'color': color,
    };
  }
}

class Workshop {
  final int id;
  final String name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final bool isActive;
  final double commissionRate;

  Workshop({
    required this.id,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.phone,
    required this.isActive,
    required this.commissionRate,
  });

  factory Workshop.fromJson(Map<String, dynamic> json) {
    return Workshop(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      phone: json['phone'],
      isActive: json['is_active'],
      commissionRate: json['commission_rate']?.toDouble() ?? 0.1,
    );
  }
}

class Technician {
  final int id;
  final String name;
  final String? phone;
  final bool isAvailable;
  final double? currentLatitude;
  final double? currentLongitude;
  final int workshopId;

  Technician({
    required this.id,
    required this.name,
    this.phone,
    required this.isAvailable,
    this.currentLatitude,
    this.currentLongitude,
    required this.workshopId,
  });

  factory Technician.fromJson(Map<String, dynamic> json) {
    return Technician(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      isAvailable: json['is_available'],
      currentLatitude: json['current_latitude']?.toDouble(),
      currentLongitude: json['current_longitude']?.toDouble(),
      workshopId: json['workshop_id'],
    );
  }
}

class Offer {
  final int id;
  final int incidentId;
  final int workshopId;
  final int? technicianId;
  final double amount;
  final int? estimatedArrivalTime;
  final String? notes;
  final String status;
  final DateTime createdAt;
  final Workshop? workshop;
  final Technician? technician;

  Offer({
    required this.id,
    required this.incidentId,
    required this.workshopId,
    this.technicianId,
    required this.amount,
    this.estimatedArrivalTime,
    this.notes,
    required this.status,
    required this.createdAt,
    this.workshop,
    this.technician,
  });

  factory Offer.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    final parsedAmount = rawAmount is num
        ? rawAmount.toDouble()
        : double.tryParse(rawAmount?.toString() ?? '') ?? 0;

    final rawEta = json['estimated_arrival_time'];
    final parsedEta = rawEta is int ? rawEta : int.tryParse(rawEta?.toString() ?? '');
    // Backend stores ETA as seconds (for incidents and offers). Convert to minutes for display in the mobile UI.
    final parsedEtaMinutes = parsedEta != null ? (parsedEta ~/ 60) : null;

    return Offer(
      id: json['id'],
      incidentId: json['incident_id'],
      workshopId: json['workshop_id'],
      technicianId: json['technician_id'],
      amount: parsedAmount,
      estimatedArrivalTime: parsedEtaMinutes,
      notes: json['notes'],
      status: (json['status']?.toString() ?? 'pending').toLowerCase(),
      createdAt: DateTime.parse(json['created_at']),
      workshop:
          json['workshop'] != null ? Workshop.fromJson(json['workshop']) : null,
      technician: json['technician'] != null
          ? Technician.fromJson(json['technician'])
          : null,
    );
  }
}

class Payment {
  final int id;
  final int incidentId;
  final double amount;
  final double commissionRate;
  final double commissionAmount;
  final double workshopAmount;
  final String paymentMethod;
  final String status;
  final DateTime? paidAt;
  final DateTime createdAt;

  Payment({
    required this.id,
    required this.incidentId,
    required this.amount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.workshopAmount,
    required this.paymentMethod,
    required this.status,
    this.paidAt,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      incidentId: json['incident_id'],
      amount: json['amount']?.toDouble() ?? 0,
      commissionRate: json['commission_percentage']?.toDouble() ?? 0,
      commissionAmount: json['commission_amount']?.toDouble() ?? 0,
      workshopAmount: json['workshop_earnings']?.toDouble() ?? 0,
      paymentMethod: json['payment_method'],
      status: json['is_paid'] == true ? 'paid' : 'pending',
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class IncidentHistory {
  final int id;
  final int incidentId;
  final String status;
  final String? note;
  final DateTime timestamp;

  IncidentHistory({
    required this.id,
    required this.incidentId,
    required this.status,
    this.note,
    required this.timestamp,
  });

  factory IncidentHistory.fromJson(Map<String, dynamic> json) {
    return IncidentHistory(
      id: json['id'],
      incidentId: json['incident_id'],
      status: (json['status']?.toString() ?? 'pending').toLowerCase(),
      note: json['note'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

class Incident {
  final int? id;
  final String description;
  final String status;
  final double? latitude;
  final double? longitude;
  final String? locationText;
  final int? vehicleId;
  final User? user;
  final Vehicle? vehicle;
  final DateTime? createdAt;
  // CICLO 2 fields
  final String priority;
  final String? classification;
  final String? aiSummary;
  final int? workshopId;
  final int? technicianId;
  final Workshop? workshop;
  final Technician? technician;
  final DateTime? estimatedArrivalTime;
  final int? remainingDistanceMeters;
  final String? routePolyline;
  final DateTime? lastEtaUpdateAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? photoUrl;
  final Payment? payment;

  Incident({
    this.id,
    required this.description,
    this.status = 'pending',
    this.latitude,
    this.longitude,
    this.locationText,
    this.vehicleId,
    this.user,
    this.vehicle,
    this.createdAt,
    this.priority = 'medium',
    this.classification,
    this.aiSummary,
    this.workshopId,
    this.technicianId,
    this.workshop,
    this.technician,
    this.estimatedArrivalTime,
    this.remainingDistanceMeters,
    this.routePolyline,
    this.lastEtaUpdateAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.photoUrl,
    this.payment,
  });

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'],
      description: json['description'],
      status: json['status'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      locationText: json['location_text'],
      vehicleId: json['vehicle_id'],
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      vehicle:
          json['vehicle'] != null ? Vehicle.fromJson(json['vehicle']) : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      priority: json['priority'] ?? 'medium',
      classification: json['classification'],
      aiSummary: json['ai_summary'],
      workshopId: json['workshop_id'],
      technicianId: json['technician_id'],
      workshop:
          json['workshop'] != null ? Workshop.fromJson(json['workshop']) : null,
      technician: json['technician'] != null
          ? Technician.fromJson(json['technician'])
          : null,
      estimatedArrivalTime: json['estimated_arrival_time'] != null
          ? (json['estimated_arrival_time'] is int
              ? DateTime.now()
                  .add(Duration(seconds: json['estimated_arrival_time']))
              : DateTime.parse(json['estimated_arrival_time'].toString()))
          : null,
      remainingDistanceMeters: json['remaining_distance_meters']?.toInt(),
      routePolyline: json['route_polyline'],
      lastEtaUpdateAt: json['last_eta_update_at'] != null
          ? DateTime.parse(json['last_eta_update_at'].toString())
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'])
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'])
          : null,
      photoUrl: json['photo_url'],
      payment:
          json['payment'] != null ? Payment.fromJson(json['payment']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'vehicle_id': vehicleId,
      'latitude': latitude,
      'longitude': longitude,
      'location_text': locationText,
      'priority': priority,
      'photo_url': photoUrl,
    };
  }
}

class RentalVehicle {
  final int id;
  final String companyName;
  final String vehicleType; // 'automovil' or 'camioneta'
  final String vehicleName;
  final String characteristics;
  final String? photoUrl;
  final String whatsappNumber;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  RentalVehicle({
    required this.id,
    required this.companyName,
    required this.vehicleType,
    required this.vehicleName,
    required this.characteristics,
    this.photoUrl,
    required this.whatsappNumber,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RentalVehicle.fromJson(Map<String, dynamic> json) {
    return RentalVehicle(
      id: json['id'],
      companyName: json['company_name'],
      vehicleType: json['vehicle_type'],
      vehicleName: json['vehicle_name'],
      characteristics: json['characteristics'],
      photoUrl: json['photo_url'],
      whatsappNumber: json['whatsapp_number'],
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class AppNotification {
  final int id;
  final int userId;
  final int? incidentId;
  final String title;
  final String message;
  final String notificationType;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    this.incidentId,
    required this.title,
    required this.message,
    required this.notificationType,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'],
      userId: json['user_id'],
      incidentId: json['incident_id'],
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? 'general',
      isRead: json['is_read'] == true,
      createdAt: (() {
        try {
          final s = json['created_at']?.toString();
          if (s == null || s.isEmpty) return DateTime.now();
          final parsed = DateTime.tryParse(s);
          return parsed ?? DateTime.now();
        } catch (_) {
          return DateTime.now();
        }
      })(),
    );
  }
}
