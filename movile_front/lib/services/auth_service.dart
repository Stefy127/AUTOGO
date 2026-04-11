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

  Future<bool> login(String email, String password) async {
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
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
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
      return await login(email, password);
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

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }
}
