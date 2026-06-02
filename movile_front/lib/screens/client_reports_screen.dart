import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models/report_models.dart';
import '../services/auth_service.dart';
import '../services/file_download_helper.dart';
import '../services/reports_service.dart';

class ClientReportsScreen extends StatefulWidget {
  const ClientReportsScreen({super.key});

  @override
  State<ClientReportsScreen> createState() => _ClientReportsScreenState();
}

class _ClientReportsScreenState extends State<ClientReportsScreen> {
  final ReportsService _reportsService = ReportsService();
  final TextEditingController _incidentTypeController = TextEditingController();
  final stt.SpeechToText _speechToText = stt.SpeechToText();

  String _status = '';
  String _paymentMethod = '';
  int? _vehicleIdFilter;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _loading = false;
  bool _exportingPdf = false;
  bool _exportingExcel = false;
  bool _speechAvailable = false;
  bool _isListening = false;
  bool _isProcessingVoice = false;
  String _recognizedText = '';
  List<String> _voiceWarnings = [];
  String? _error;

  OperationalReportSummary _summary = OperationalReportSummary.empty();
  List<OperationalReportItem> _items = [];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _incidentTypeController.dispose();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    final available = await _speechToText.initialize();
    if (!mounted) return;
    setState(() => _speechAvailable = available);
  }

  OperationalReportRequest _buildPayload() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return OperationalReportRequest(
      startDate: _startDate != null ? dateFormat.format(_startDate!) : null,
      endDate: _endDate != null ? dateFormat.format(_endDate!) : null,
      incidentType: _incidentTypeController.text.trim().isEmpty ? null : _incidentTypeController.text.trim(),
      status: _status.isEmpty ? null : _status,
      vehicleId: (_vehicleIdFilter != null && _vehicleIdFilter! > 0) ? _vehicleIdFilter : null,
      paymentMethod: _paymentMethod.isEmpty ? null : _paymentMethod,
    );
  }

  Future<void> _queryReports() async {
    final token = context.read<AuthService>().token;
    if (token == null || token.isEmpty) {
      _showMessage('Debes iniciar sesión para consultar reportes.', isError: true);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _reportsService.queryOperationalReport(
        token: token,
        payload: _buildPayload(),
      );
      if (!mounted) return;
      setState(() {
        _summary = response.summary;
        _items = response.items;
      });
    } on ReportsServiceException catch (e) {
      if (!mounted) return;
      setState(() => _error = _mapError(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No se pudo consultar el reporte.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _exportPdf() async {
    await _exportFile(isPdf: true);
  }

  Future<void> _exportExcel() async {
    await _exportFile(isPdf: false);
  }

  Future<void> _exportFile({required bool isPdf}) async {
    final token = context.read<AuthService>().token;
    if (token == null || token.isEmpty) {
      _showMessage('Debes iniciar sesión para exportar reportes.', isError: true);
      return;
    }

    setState(() {
      if (isPdf) {
        _exportingPdf = true;
      } else {
        _exportingExcel = true;
      }
      _error = null;
    });

    try {
      final payload = _buildPayload();
      final bytes = isPdf
          ? await _reportsService.exportOperationalReportPdf(token: token, payload: payload)
          : await _reportsService.exportOperationalReportExcel(token: token, payload: payload);
      final fileName = isPdf ? 'reporte_operacional.pdf' : 'reporte_operacional.xlsx';
      final message = await saveReportFile(bytes, fileName);
      if (!mounted) return;
      _showMessage(message);
    } on ReportsServiceException catch (e) {
      if (!mounted) return;
      _showMessage(_mapError(e), isError: true);
    } catch (_) {
      if (!mounted) return;
      _showMessage('No se pudo exportar el archivo.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          if (isPdf) {
            _exportingPdf = false;
          } else {
            _exportingExcel = false;
          }
        });
      }
    }
  }

  Future<void> _startVoiceInput() async {
    if (!_speechAvailable) {
      _showMessage('El reconocimiento de voz no está disponible en este dispositivo.', isError: true);
      return;
    }
    if (_isListening || _isProcessingVoice) return;

    setState(() {
      _voiceWarnings = [];
      _recognizedText = '';
      _isListening = true;
    });

    await _speechToText.listen(
      localeId: 'es_ES',
      onResult: (result) async {
        if (!result.finalResult) return;
        final recognized = result.recognizedWords.trim();
        setState(() {
          _recognizedText = recognized;
          _isListening = false;
          _isProcessingVoice = true;
        });
        await _applyVoiceCommand(recognized);
      },
      listenFor: const Duration(seconds: 7),
      pauseFor: const Duration(seconds: 2),
    );
  }

  Future<void> _applyVoiceCommand(String text) async {
    final token = context.read<AuthService>().token;
    if (token == null || token.isEmpty) {
      setState(() => _isProcessingVoice = false);
      _showMessage('Debes iniciar sesión para usar reportes por voz.', isError: true);
      return;
    }

    try {
      final parsed = await _reportsService.voiceParse(token: token, text: text);
      _applyParsedFilters(parsed.filters);
      setState(() => _voiceWarnings = parsed.warnings);

      if (parsed.action == 'pdf') {
        await _exportPdf();
      } else if (parsed.action == 'excel') {
        await _exportExcel();
      } else if (parsed.action == 'query') {
        await _queryReports();
      } else {
        _showMessage('Comando aplicado. Revisa los filtros.');
      }
    } on ReportsServiceException catch (e) {
      _showMessage(_mapError(e), isError: true);
    } catch (_) {
      _showMessage('No se pudo procesar el comando de voz.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isProcessingVoice = false);
      }
    }
  }

  void _applyParsedFilters(OperationalReportRequest filters) {
    final safeVehicleId = (filters.vehicleId != null && filters.vehicleId! > 0) ? filters.vehicleId : null;
    setState(() {
      _startDate = _parseDate(filters.startDate);
      _endDate = _parseDate(filters.endDate);
      _incidentTypeController.text = filters.incidentType ?? '';
      _status = filters.status ?? '';
      _paymentMethod = filters.paymentMethod ?? '';
      _vehicleIdFilter = safeVehicleId;
    });
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final dateOnly = value.length >= 10 ? value.substring(0, 10) : value;
    return DateTime.tryParse(dateOnly);
  }

  String _mapError(ReportsServiceException e) {
    if (e.statusCode == 401 || e.statusCode == 403) {
      return 'No tienes permisos para consultar estos reportes.';
    }
    if (e.statusCode == 404) {
      return 'No se encontraron datos para la consulta.';
    }
    return 'Error ${e.statusCode}: ${e.detail}';
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _statusLabel(String status) {
    const map = {
      'pending': 'Pendiente',
      'waiting_offers': 'Esperando ofertas',
      'assigned': 'Asignado',
      'accepted': 'Aceptado',
      'in_progress': 'En progreso',
      'completed': 'Completado',
      'cancelled': 'Cancelado',
    };
    return map[status] ?? status;
  }

  String _paymentMethodLabel(String method) {
    const map = {
      '': 'Todos',
      'cash': 'Efectivo',
      'transfer': 'Transferencia',
      'qr': 'QR',
    };
    return map[method] ?? method;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _incidentTypeController.clear();
      _status = '';
      _paymentMethod = '';
      _vehicleIdFilter = null;
      _error = null;
      _voiceWarnings = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Reportes')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _queryReports,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Consulta reportes de tus emergencias y servicios',
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              _buildFiltersCard(),
              const SizedBox(height: 14),
              _buildVoiceCard(theme),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
              else ...[
                _buildKpis(),
                const SizedBox(height: 16),
                _buildList(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersCard() {
    final formatter = DateFormat('yyyy-MM-dd');
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            Text('Ajusta fechas y criterios para consultar o exportar reportes.', style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: true),
                    child: Text(_startDate == null ? 'Fecha inicio' : formatter.format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isStart: false),
                    child: Text(_endDate == null ? 'Fecha fin' : formatter.format(_endDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _incidentTypeController,
              decoration: const InputDecoration(labelText: 'Tipo de emergencia', hintText: 'Ej: battery'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _status,
              items: const [
                DropdownMenuItem(value: '', child: Text('Todos los estados')),
                DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                DropdownMenuItem(value: 'waiting_offers', child: Text('Esperando ofertas')),
                DropdownMenuItem(value: 'assigned', child: Text('Asignado')),
                DropdownMenuItem(value: 'accepted', child: Text('Aceptado')),
                DropdownMenuItem(value: 'in_progress', child: Text('En progreso')),
                DropdownMenuItem(value: 'completed', child: Text('Completado')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelado')),
              ],
              onChanged: (value) => setState(() => _status = value ?? ''),
              decoration: const InputDecoration(labelText: 'Estado'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              items: const [
                DropdownMenuItem(value: '', child: Text('Todos los métodos')),
                DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                DropdownMenuItem(value: 'transfer', child: Text('Transferencia')),
                DropdownMenuItem(value: 'qr', child: Text('QR')),
              ],
              onChanged: (value) => setState(() => _paymentMethod = value ?? ''),
              decoration: const InputDecoration(labelText: 'Método de pago'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  onPressed: _loading ? null : _queryReports,
                  child: const Text('Consultar'),
                ),
                OutlinedButton(onPressed: _clearFilters, child: const Text('Limpiar filtros')),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF475569), foregroundColor: Colors.white),
                  onPressed: _exportingPdf ? null : _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(_exportingPdf ? 'Exportando...' : 'Exportar PDF'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF475569), foregroundColor: Colors.white),
                  onPressed: _exportingExcel ? null : _exportExcel,
                  icon: const Icon(Icons.table_view),
                  label: Text(_exportingExcel ? 'Exportando...' : 'Exportar Excel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceCard(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Consulta por voz', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text(
              'Usa tu voz para llenar filtros o generar acciones rápidas. Habla claro y cerca del micrófono.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              'Ejemplos: “reporte de mayo completadas en PDF”, “reporte con cliente id 3”, “últimos 7 días en Excel”.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: (_isListening || _isProcessingVoice) ? null : _startVoiceInput,
                  child: Ink(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isListening
                            ? [const Color(0xFFEF4444), const Color(0xFFF97316)]
                            : [const Color(0xFF3B82F6), const Color(0xFF6366F1)],
                      ),
                      boxShadow: const [BoxShadow(color: Color(0x334F46E5), blurRadius: 14, offset: Offset(0, 6))],
                    ),
                    child: const Center(child: Text('🎤', style: TextStyle(fontSize: 22))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _isListening ? 'Escuchando...' : (_isProcessingVoice ? 'Procesando comando...' : 'Usar voz'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (_recognizedText.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Comando reconocido: "$_recognizedText"'),
            ],
            if (_voiceWarnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._voiceWarnings.map((w) => Text('• $w', style: const TextStyle(color: Colors.orange))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKpis() {
    final kpis = <Map<String, dynamic>>[
      {'label': 'Total incidentes', 'value': _summary.totalIncidents.toString(), 'colorA': const Color(0xFFDBEAFE), 'colorB': const Color(0xFFBFDBFE)},
      {'label': 'Pendientes', 'value': _summary.pending.toString(), 'colorA': const Color(0xFFFFEDD5), 'colorB': const Color(0xFFFED7AA)},
      {'label': 'En progreso', 'value': _summary.inProgress.toString(), 'colorA': const Color(0xFFCFFAFE), 'colorB': const Color(0xFFA5F3FC)},
      {'label': 'Completados', 'value': _summary.completed.toString(), 'colorA': const Color(0xFFDCFCE7), 'colorB': const Color(0xFFBBF7D0)},
      {'label': 'Cancelados', 'value': _summary.cancelled.toString(), 'colorA': const Color(0xFFFEE2E2), 'colorB': const Color(0xFFFECACA)},
      {'label': 'Monto total', 'value': _summary.totalAmount.toStringAsFixed(2), 'colorA': const Color(0xFFFEF9C3), 'colorB': const Color(0xFFFEF08A)},
      {'label': 'Pagos realizados', 'value': _summary.totalPaid.toString(), 'colorA': const Color(0xFFEEF2FF), 'colorB': const Color(0xFFE0E7FF)},
      {'label': 'Pagos pendientes', 'value': _summary.totalUnpaid.toString(), 'colorA': const Color(0xFFFAE8FF), 'colorB': const Color(0xFFF5D0FE)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kpis.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final item = kpis[index];
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [item['colorA'] as Color, item['colorB'] as Color]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x220F172A), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['label'] as String, style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(item['value'] as String, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No hay reportes para los filtros seleccionados'),
        ),
      );
    }

    return Column(
      children: _items.map((item) {
        final vehicle = '${item.vehicleBrand ?? '-'} ${item.vehicleModel ?? '-'} (${item.vehiclePlate ?? '-'})';
        final dateText = item.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(item.createdAt!) : '-';
        final statusColor = _statusColor(item.status);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Emergencia #${item.incidentId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
                      child: Text(_statusLabel(item.status), style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Fecha: $dateText'),
                Text('Tipo: ${item.classification ?? 'Sin clasificar'}'),
                Text('Vehículo: $vehicle'),
                Text('Taller: ${item.workshopName ?? '-'}'),
                Text('Monto: ${item.paymentAmount.toStringAsFixed(2)}'),
                Text('Método de pago: ${_paymentMethodLabel(item.paymentMethod ?? '')}'),
                Row(
                  children: [
                    const Text('Pagado: '),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.paymentIsPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item.paymentIsPaid ? 'Sí' : 'No',
                        style: TextStyle(
                          color: item.paymentIsPaid ? const Color(0xFF166534) : const Color(0xFFB91C1C),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFC2410C);
      case 'waiting_offers':
        return const Color(0xFFA16207);
      case 'assigned':
        return const Color(0xFF4338CA);
      case 'accepted':
        return const Color(0xFF7E22CE);
      case 'in_progress':
        return const Color(0xFF0E7490);
      case 'completed':
        return const Color(0xFF15803D);
      case 'cancelled':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFF334155);
    }
  }
}
