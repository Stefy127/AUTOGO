import 'dart:convert';
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
      defaultValue: 'https://autogo-backend-g4ctv55smq-uc.a.run.app',
    );
    try {
      final envValue = dotenv.env['API_BASE_URL'];
      if (envValue != null && envValue.isNotEmpty) return envValue;
    } catch (_) {}
    return fromDefine;
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

  Future<dynamic> put(String endpoint, Map<String, dynamic> data, {String? token}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final response = await http.put(
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
      contentType: http_parser.MediaType(parts[0], parts.length > 1 ? parts[1] : '*'),
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamed);
    return _handleResponse(response);
  }
}
