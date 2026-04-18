import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // API URL configurable at runtime:
  // flutter run --dart-define=API_BASE_URL=http://192.168.110.17:8000
  // If not provided, defaults to Android emulator host bridge.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const _timeout = Duration(seconds: 15);

  Future<dynamic> get(String endpoint, {String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.get(url, headers: headers).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> data, {String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> data, {String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.patch(
      url,
      headers: headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint, {String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.delete(url, headers: headers).timeout(_timeout);
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error: ${response.statusCode} - ${response.body}');
    }
  }
}
