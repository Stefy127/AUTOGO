import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/models.dart';
import 'api_service.dart';
import 'auth_service.dart';

class MobileNotificationService with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  final List<AppNotification> _notifications = [];
  final Set<int> _shownNotificationIds = <int>{};

  Timer? _pollTimer;
  String? _token;
  bool _initialized = false;
  bool _loading = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(initSettings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> updateAuth(AuthService authService) async {
    await _ensureInitialized();

    final newToken = authService.token;
    if (newToken == null) {
      _token = null;
      _pollTimer?.cancel();
      _notifications.clear();
      _shownNotificationIds.clear();
      notifyListeners();
      return;
    }

    if (_token == newToken) return;

    _token = newToken;
    await refresh();

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refresh();
    });
  }

  Future<void> refresh() async {
    if (_loading || _token == null) return;
    _loading = true;

    try {
      final response = await _apiService.get('/notifications?limit=50', token: _token);
      final fetched = (response as List)
          .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
          .toList();

      for (final n in fetched) {
        if (!n.isRead && !_shownNotificationIds.contains(n.id)) {
          _shownNotificationIds.add(n.id);
          await _showSystemNotification(n);
        }
      }

      _notifications
        ..clear()
        ..addAll(fetched);
      notifyListeners();
    } catch (_) {
      // Silent: notification refresh should not break UX.
    } finally {
      _loading = false;
    }
  }

  Future<void> markAsRead(int notificationId) async {
    if (_token == null) return;

    await _apiService.patch('/notifications/$notificationId/read', {}, token: _token);

    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx >= 0) {
      final old = _notifications[idx];
      _notifications[idx] = AppNotification(
        id: old.id,
        userId: old.userId,
        incidentId: old.incidentId,
        title: old.title,
        message: old.message,
        notificationType: old.notificationType,
        isRead: true,
        createdAt: old.createdAt,
      );
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    if (_token == null) return;

    await _apiService.patch('/notifications/read-all', {}, token: _token);

    for (var i = 0; i < _notifications.length; i++) {
      final old = _notifications[i];
      _notifications[i] = AppNotification(
        id: old.id,
        userId: old.userId,
        incidentId: old.incidentId,
        title: old.title,
        message: old.message,
        notificationType: old.notificationType,
        isRead: true,
        createdAt: old.createdAt,
      );
    }
    notifyListeners();
  }

  Future<void> _showSystemNotification(AppNotification notification) async {
    const androidDetails = AndroidNotificationDetails(
      'autogo_alerts',
      'AutoGo Alerts',
      channelDescription: 'Alertas de ofertas y estado del mecanico',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      notification.id,
      notification.title,
      notification.message,
      details,
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
