import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  // API URL configurable at runtime:
  // flutter run --dart-define=API_BASE_URL=https://autogo-backend-g4ctv55smq-uc.a.run.app
  // If not provided, defaults to production backend on Cloud Run.
  static String get baseUrl {
    const fromDefine = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: '',
    );

    try {
      final envValue = dotenv.env['API_BASE_URL'];
      final configuredValue = fromDefine.isNotEmpty ? fromDefine : envValue;
      if (configuredValue != null && configuredValue.isNotEmpty) {
        return _normalizeForPlatform(configuredValue);
      }
    } catch (_) {}

    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    return 'http://10.0.2.2:8000';
  }

  static String _normalizeForPlatform(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return value;

    if (kIsWeb && uri.host == '10.0.2.2') {
      return uri.replace(host: 'localhost').toString();
    }

    return value;
  }

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

  Future<dynamic> post(String endpoint, Map<String, dynamic> data,
      {String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http
        .post(
          url,
          headers: headers,
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> data,
      {String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http
        .patch(
          url,
          headers: headers,
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> data,
      {String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http
        .put(
          url,
          headers: headers,
          body: jsonEncode(data),
        )
        .timeout(_timeout);
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

  /// Upload a single file as multipart/form-data.
  /// [fields] are additional string form fields.
  Future<dynamic> postMultipart(
    String endpoint,
    String fileField,
    String filePath,
    String mimeType, {
    Map<String, String>? fields,
    String? token,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final request = http.MultipartRequest('POST', url);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (fields != null) request.fields.addAll(fields);

    final parts = mimeType.split('/');
    request.files.add(await http.MultipartFile.fromPath(
      fileField,
      filePath,
      contentType:
          http_parser.MediaType(parts[0], parts.length > 1 ? parts[1] : '*'),
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }
}
