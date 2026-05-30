import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/offline_emergency.dart';

class OfflineEmergencyStorageService {
  static const String storageKey = 'offline_emergency_active';

  Future<OfflineEmergency?> getActiveEmergency() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return OfflineEmergency.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasActiveEmergency() async {
    final emergency = await getActiveEmergency();
    if (emergency == null) return false;
    return _isActiveStatus(emergency.syncStatus);
  }

  Future<void> saveEmergency(OfflineEmergency emergency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(emergency.toJson()));
  }

  Future<void> updateEmergency(OfflineEmergency emergency) async {
    await saveEmergency(emergency);
  }

  Future<void> deleteEmergency() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  bool _isActiveStatus(String status) {
    return status == 'pending' || status == 'syncing' || status == 'failed';
  }
}
