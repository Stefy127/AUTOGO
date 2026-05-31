import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../models/report_models.dart';
import 'api_service.dart';

class ReportsService {
  static const _timeout = Duration(seconds: 30);

  Future<OperationalReportResponse> queryOperationalReport({
    required String token,
    required OperationalReportRequest payload,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}/reports/operational/query');
    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload.toJson()),
        )
        .timeout(_timeout);

    _throwIfError(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return OperationalReportResponse.fromJson(json);
  }

  Future<Uint8List> exportOperationalReportPdf({
    required String token,
    required OperationalReportRequest payload,
  }) async {
    return _exportBinary(
      token: token,
      payload: payload,
      endpoint: '/reports/operational/export/pdf',
    );
  }

  Future<Uint8List> exportOperationalReportExcel({
    required String token,
    required OperationalReportRequest payload,
  }) async {
    return _exportBinary(
      token: token,
      payload: payload,
      endpoint: '/reports/operational/export/excel',
    );
  }

  Future<Uint8List> _exportBinary({
    required String token,
    required OperationalReportRequest payload,
    required String endpoint,
  }) async {
    final url = Uri.parse('${ApiService.baseUrl}$endpoint');
    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload.toJson()),
        )
        .timeout(_timeout);

    _throwIfError(response);
    return response.bodyBytes;
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String detail = response.body;
    try {
      final parsed = jsonDecode(response.body);
      if (parsed is Map && parsed['detail'] != null) {
        detail = parsed['detail'].toString();
      }
    } catch (_) {}
    throw ReportsServiceException(statusCode: response.statusCode, detail: detail);
  }
}

class ReportsServiceException implements Exception {
  final int statusCode;
  final String detail;

  ReportsServiceException({required this.statusCode, required this.detail});
}
