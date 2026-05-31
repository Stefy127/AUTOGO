import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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

  String _status = '';
  String _paymentMethod = '';
  DateTime? _startDate;
  DateTime? _endDate;

  bool _loading = false;
  bool _exportingPdf = false;
  bool _exportingExcel = false;
  String? _error;

  OperationalReportSummary _summary = OperationalReportSummary.empty();
  List<OperationalReportItem> _items = [];

  @override
  void dispose() {
    _incidentTypeController.dispose();
    super.dispose();
  }

  OperationalReportRequest _buildPayload() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return OperationalReportRequest(
      startDate: _startDate != null ? dateFormat.format(_startDate!) : null,
      endDate: _endDate != null ? dateFormat.format(_endDate!) : null,
      incidentType: _incidentTypeController.text.trim().isEmpty ? null : _incidentTypeController.text.trim(),
      status: _status.isEmpty ? null : _status,
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
      'card': 'Tarjeta',
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
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.mic_off, color: Colors.blueGrey),
                    SizedBox(width: 8),
                    Expanded(child: Text('Espacio reservado para búsqueda por voz')),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildFiltersCard(),
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
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
                DropdownMenuItem(value: 'card', child: Text('Tarjeta')),
              ],
              onChanged: (value) => setState(() => _paymentMethod = value ?? ''),
              decoration: const InputDecoration(labelText: 'Método de pago'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(onPressed: _loading ? null : _queryReports, child: const Text('Consultar')),
                OutlinedButton(onPressed: _clearFilters, child: const Text('Limpiar filtros')),
                ElevatedButton.icon(
                  onPressed: _exportingPdf ? null : _exportPdf,
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(_exportingPdf ? 'Exportando...' : 'Exportar PDF'),
                ),
                ElevatedButton.icon(
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

  Widget _buildKpis() {
    final kpis = <MapEntry<String, String>>[
      MapEntry('Total incidentes', _summary.totalIncidents.toString()),
      MapEntry('Pendientes', _summary.pending.toString()),
      MapEntry('En progreso', _summary.inProgress.toString()),
      MapEntry('Completados', _summary.completed.toString()),
      MapEntry('Cancelados', _summary.cancelled.toString()),
      MapEntry('Monto total', _summary.totalAmount.toStringAsFixed(2)),
      MapEntry('Pagos realizados', _summary.totalPaid.toString()),
      MapEntry('Pagos pendientes', _summary.totalUnpaid.toString()),
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
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.key, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(item.value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Emergencia #${item.incidentId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Fecha: $dateText'),
                Text('Estado: ${_statusLabel(item.status)}'),
                Text('Tipo: ${item.classification ?? 'Sin clasificar'}'),
                Text('Vehículo: $vehicle'),
                Text('Taller: ${item.workshopName ?? '-'}'),
                Text('Monto: ${item.paymentAmount.toStringAsFixed(2)}'),
                Text('Método de pago: ${_paymentMethodLabel(item.paymentMethod ?? '')}'),
                Text('Pagado: ${item.paymentIsPaid ? 'Sí' : 'No'}'),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
