import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/models.dart';

class AuthService with ChangeNotifier {
  String? _token;
  User? _currentUser;
  final ApiService _apiService = ApiService();

  String? get token => _token;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _token != null;

  AuthService() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      await _loadUserProfile();
    }
    notifyListeners();
  }

  // Returns null on success, or an error message string on failure.
  Future<String?> login(String email, String password) async {
    try {
      final response = await _apiService.post('/auth/login/json', {
        'email': email,
        'password': password,
      });

      _token = response['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);

      await _loadUserProfile();
      notifyListeners();
      return null;
    } on TimeoutException {
      return 'No se pudo conectar al servidor. Verifica tu conexión.';
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('400')) {
        return 'Email o contraseña incorrectos.';
      }
      if (msg.contains('SocketException') || msg.contains('Connection refused') || msg.contains('Failed host lookup')) {
        return 'No se pudo conectar al servidor. Verifica tu conexión.';
      }
      print('Login error: $e');
      return 'Error al iniciar sesión. Intenta de nuevo.';
    }
  }

  Future<bool> register(String email, String password, String fullName, String? phone) async {
    try {
      await _apiService.post('/auth/register', {
        'email': email,
        'password': password,
        'full_name': fullName,
        'phone': phone,
        'role': 'client',
      });
      return await login(email, password) == null;
    } catch (e) {
      print('Register error: $e');
      return false;
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final response = await _apiService.get('/users/profile', token: _token);
      _currentUser = User.fromJson(response);
      notifyListeners();
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<bool> refreshUserProfile() async {
    try {
      await _loadUserProfile();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String?> updateProfile({
    required String fullName,
    required String email,
    String? phone,
  }) async {
    try {
      final response = await _apiService.put(
        '/users/profile',
        {
          'full_name': fullName,
          'email': email,
          'phone': phone,
        },
        token: _token,
      );

      _currentUser = User.fromJson(response);
      notifyListeners();
      return null;
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('400') && msg.contains('email')) {
        return 'El email ya está en uso.';
      }
      if (msg.contains('422')) {
        return 'Datos inválidos. Revisa los campos del formulario.';
      }
      return 'No se pudo actualizar el perfil.';
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }

  Future<bool> deleteMyAccount() async {
    try {
      await _apiService.delete('/users/profile', token: _token);
      await logout();
      return true;
    } catch (e) {
      print('Delete account error: $e');
      return false;
    }
  }
}
