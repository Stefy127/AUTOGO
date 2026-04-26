import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class PaymentQrScreen extends StatefulWidget {
  final Incident incident;

  const PaymentQrScreen({super.key, required this.incident});

  @override
  State<PaymentQrScreen> createState() => _PaymentQrScreenState();
}

class _PaymentQrScreenState extends State<PaymentQrScreen> {
  bool _loading = true;
  String? _error;
  String? _workshopQrImageUrl;
  late final String _reference;

  @override
  void initState() {
    super.initState();
    _reference = 'AG-${widget.incident.id}-${DateTime.now().millisecondsSinceEpoch}';
    _loadWorkshopQrConfig();
  }

  Future<void> _loadWorkshopQrConfig() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final workshopId = widget.incident.workshopId;
      if (workshopId == null) {
        throw Exception('No hay taller asignado para este incidente');
      }

      final response = await apiService.get(
        '/workshops/$workshopId/payment-qr',
        token: authService.token,
      );

      if (!mounted) return;
      setState(() {
        _workshopQrImageUrl = response['qr_image_url']?.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No hay QR de taller disponible: $e';
        _loading = false;
      });
    }
  }

  String get _qrPayload {
    final amount = widget.incident.payment?.amount.toStringAsFixed(2) ?? '0.00';
    return '{"incident_id":${widget.incident.id},"amount":$amount,"reference":"$_reference"}';
  }

  Future<void> _confirmQrPayment() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    setState(() => _loading = true);
    try {
      await apiService.post(
        '/payments/incident/${widget.incident.id}/pay-qr',
        {'reference_number': _reference},
        token: authService.token,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago QR confirmado'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo confirmar el pago: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pago por QR')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                      ),
                    ),
                  if (_workshopQrImageUrl != null) ...[
                    const Text(
                      'QR del taller',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _workshopQrImageUrl!,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 120,
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: const Text('No se pudo cargar la imagen QR del taller'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const Text(
                    'Código de pago AutoGo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Monto: \$${widget.incident.payment?.amount.toStringAsFixed(2) ?? '0.00'}'),
                  Text('Incidente: #${widget.incident.id}'),
                  Text('Referencia: $_reference'),
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4)),
                        ],
                      ),
                      child: QrImageView(
                        data: _qrPayload,
                        version: QrVersions.auto,
                        size: 220,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _confirmQrPayment,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Confirmar pago (simulado)'),
                  ),
                ],
              ),
            ),
    );
  }
}
