import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import '../models/models.dart';

class TechnicianAccessService with ChangeNotifier {
  static const _storageTokenKey = 'technician_access_token';
  static const _storageNameKey = 'technician_name';

  final ApiService _apiService = ApiService();

  String? _accessToken;
  String? _technicianName;
  int? _technicianId;
  int? _workshopId;
  String? _workshopName;

  String? get accessToken => _accessToken;
  String? get technicianName => _technicianName;
  int? get technicianId => _technicianId;
  int? get workshopId => _workshopId;
  String? get workshopName => _workshopName;
  bool get isAuthenticated => _accessToken != null;

  TechnicianAccessService() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_storageTokenKey);
    _technicianName = prefs.getString(_storageNameKey);
    notifyListeners();
  }

  Future<String?> access({required String code, required String name}) async {
    try {
      final response = await _apiService.post('/technician/access', {
        'code': code,
        'name': name,
      });

      _accessToken = response['access_token']?.toString();
      _technicianName = response['technician_name']?.toString();
      _technicianId = response['technician_id'] as int?;
      _workshopId = response['workshop_id'] as int?;
      _workshopName = response['workshop_name']?.toString();

      if (_accessToken == null) {
        return 'No se recibió token de acceso';
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageTokenKey, _accessToken!);
      if (_technicianName != null) {
        await prefs.setString(_storageNameKey, _technicianName!);
      }

      notifyListeners();
      return null;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401')) {
        return 'Código o nombre inválidos';
      }
      return 'No se pudo acceder: $e';
    }
  }

  Future<List<Incident>> getIncidents() async {
    if (_accessToken == null) {
      throw Exception('Sesión de técnico no iniciada');
    }

    final response = await _apiService.get(
      '/technician/incidents',
      token: _accessToken,
    );

    return (response as List)
        .map((item) => Incident.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Incident> updateIncidentStatus(int incidentId, String status) async {
    if (_accessToken == null) {
      throw Exception('Sesión de técnico no iniciada');
    }

    final response = await _apiService.patch(
      '/technician/incidents/$incidentId/status',
      {'status': status},
      token: _accessToken,
    );

    return Incident.fromJson(response as Map<String, dynamic>);
  }

  Future<String> getIncidentPaymentQrUrl(int incidentId) async {
    if (_accessToken == null) {
      throw Exception('Sesión de técnico no iniciada');
    }

    final response = await _apiService.get(
      '/technician/incidents/$incidentId/payment-qr',
      token: _accessToken,
    );

    return (response as Map<String, dynamic>)['qr_image_url']?.toString() ?? '';
  }

  Future<Payment> confirmPayment({required int incidentId, required String paymentMethod}) async {
    if (_accessToken == null) {
      throw Exception('Sesión de técnico no iniciada');
    }

    final response = await _apiService.post(
      '/technician/payments/confirm',
      {
        'incident_id': incidentId,
        'payment_method': paymentMethod,
      },
      token: _accessToken,
    );

    return Payment.fromJson(response as Map<String, dynamic>);
  }

  Future<void> logout() async {
    _accessToken = null;
    _technicianName = null;
    _technicianId = null;
    _workshopId = null;
    _workshopName = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageTokenKey);
    await prefs.remove(_storageNameKey);

    notifyListeners();
  }
}
