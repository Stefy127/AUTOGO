import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'emergency_offers_screen.dart';
import 'incident_tracking_screen_stub.dart'
  if (dart.library.io) 'incident_tracking_screen.dart';

class EmergencyListScreen extends StatefulWidget {
  const EmergencyListScreen({super.key});

  @override
  State<EmergencyListScreen> createState() => _EmergencyListScreenState();
}

class _EmergencyListScreenState extends State<EmergencyListScreen> {
  List<Incident> _incidents = [];
  bool _isLoading = true;
  int? _stripeLoadingPaymentId;
  int? _cancelLoadingIncidentId;
  Timer? _etaRefreshTimer;
  XFile? _selectedCancellationProof;
  Uint8List? _selectedCancellationProofBytes;
  bool _sendingCancellationProof = false;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
    _etaRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _showIncidentDetailsLive(Incident incident) {
    _showIncidentDetails(incident);
  }

  @override
  void dispose() {
    _etaRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadIncidents() async {
    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final response = await apiService.get('/incidents', token: authService.token);
      setState(() {
        _incidents = (response as List).map((i) => Incident.fromJson(i)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'waiting_offers':
        return Colors.deepOrange;
      case 'assigned':
        return Colors.lightBlue;
      case 'accepted':
        return Colors.blue;
      case 'on_route':
        return Colors.teal;
      case 'in_service':
      case 'in_progress':
        return Colors.indigo;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'waiting_offers':
        return 'Esperando Ofertas';
      case 'assigned':
        return 'Asignada';
      case 'accepted':
        return 'Aceptada';
      case 'on_route':
        return 'En camino';
      case 'in_service':
        return 'En atención';
      case 'in_progress':
        return 'En Proceso';
      case 'completed':
        return 'Completada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return status;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText(String priority) {
    switch (priority) {
      case 'high':
        return '🔴 Alta';
      case 'medium':
        return '🟡 Media';
      case 'low':
        return '🟢 Baja';
      default:
        return priority;
    }
  }

  bool _canShowStripeButton(Incident incident) {
    return incident.status == 'completed' &&
        incident.payment != null &&
        incident.payment!.status != 'paid';
  }

  Future<void> _payWithStripe(Incident incident) async {
    final payment = incident.payment;
    if (payment == null) return;

    setState(() => _stripeLoadingPaymentId = payment.id);

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final response = await apiService.post(
        '/payments/${payment.id}/stripe/checkout',
        {},
        token: authService.token,
      );

      final checkoutUrl = (response['checkout_url'] ?? '').toString();
      if (checkoutUrl.isEmpty) {
        throw Exception('Checkout URL vacío');
      }

      final launched = await launchUrl(
        Uri.parse(checkoutUrl),
        webOnlyWindowName: '_self',
      );

      if (!launched) {
        throw Exception('No se pudo abrir Stripe Checkout');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _stripeLoadingPaymentId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo iniciar el pago con Stripe: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _canCancelIncident(Incident incident) {
    return incident.id != null &&
        ['pending', 'waiting_offers', 'assigned', 'accepted', 'on_route', 'in_service', 'in_progress']
            .contains(incident.status);
  }

  Future<void> _cancelIncident(Incident incident) async {
    final reasonController = TextEditingController();
    final requiresReason = incident.status == 'in_service' || incident.status == 'in_progress';
    final warning = incident.status == 'on_route'
        ? 'El tecnico ya esta en camino. Se generara un pago por cancelacion del 20%.'
      : (incident.status == 'in_service' || incident.status == 'in_progress')
            ? 'La atencion ya inicio. Se generara un pago parcial del 50%.'
            : 'El servicio se cancelara sin cobro.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancelar servicio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(warning),
              if (requiresReason) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Motivo obligatorio',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Volver'),
            ),
            ElevatedButton(
              onPressed: () {
                if (requiresReason && reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('Ingresa el motivo de cancelacion')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || incident.id == null) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    setState(() => _cancelLoadingIncidentId = incident.id);

    try {
      final response = await apiService.post(
        '/incidents/${incident.id}/cancel',
        {'reason': reasonController.text.trim().isEmpty ? null : reasonController.text.trim()},
        token: authService.token,
      ) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() => _cancelLoadingIncidentId = null);

      if (response['requires_payment'] == true) {
        await _showCancellationPayment(response);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message']?.toString() ?? 'Servicio cancelado')),
        );
      }

      Navigator.pop(context);
      await _loadIncidents();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelLoadingIncidentId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo cancelar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCancellationPayment(Map<String, dynamic> data) async {
    final paymentId = data['payment_id'] as int?;
    final qrUrl = data['qr_image_url']?.toString() ?? '';
    _selectedCancellationProof = null;
    _selectedCancellationProofBytes = null;
    _sendingCancellationProof = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> pickProofImage() async {
              try {
                final picker = ImagePicker();
                final image = await picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                );
                if (image == null) return;

                final bytes = await image.readAsBytes();
                setDialogState(() {
                  _selectedCancellationProof = image;
                  _selectedCancellationProofBytes = bytes;
                });
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('No se pudo seleccionar el comprobante: $e')),
                );
              }
            }

            Future<void> submitPayment() async {
              if (paymentId == null) return;
              if (_selectedCancellationProofBytes == null) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Adjunta un comprobante de pago')),
                );
                return;
              }

              setDialogState(() => _sendingCancellationProof = true);
              try {
                final authService = Provider.of<AuthService>(context, listen: false);
                final apiService = Provider.of<ApiService>(context, listen: false);
                final mimeType = _selectedCancellationProof?.name.toLowerCase().endsWith('.png') == true
                    ? 'image/png'
                    : 'image/jpeg';
                final proofDataUrl =
                    'data:$mimeType;base64,${base64Encode(_selectedCancellationProofBytes!)}';
                final referenceNumber =
                    'AG-CANCEL-${data['incident_id'] ?? paymentId}-${DateTime.now().millisecondsSinceEpoch}';

                await apiService.post(
                  '/payments/$paymentId/confirm-qr-payment',
                  {
                    'reference_number': referenceNumber,
                    'proof_image_url': proofDataUrl,
                  },
                  token: authService.token,
                );

                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pago enviado para verificacion del taller.')),
                );
              } catch (e) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('No se pudo enviar el comprobante: $e')),
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => _sendingCancellationProof = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Pago por cancelacion'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cotizacion aceptada: \$${(data['original_offer_amount_usd'] ?? 0).toString()} USD'),
                    Text('Porcentaje aplicado: ${data['cancellation_percentage']}%'),
                    Text('Monto en USD: \$${(data['penalty_amount_usd'] ?? 0).toString()}'),
                    Text('Tipo de cambio: ${data['exchange_rate_usd_to_bob']} Bs'),
                    const SizedBox(height: 8),
                    Text(
                      'Pague exactamente ${data['penalty_amount_bob']} Bs.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (qrUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Center(child: _buildQrImage(qrUrl)),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _sendingCancellationProof ? null : pickProofImage,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Adjuntar comprobante'),
                    ),
                    if (_selectedCancellationProofBytes != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _selectedCancellationProofBytes!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedCancellationProof?.name ?? 'Comprobante adjuntado',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        'Adjunta una foto o captura del comprobante para continuar.',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: _sendingCancellationProof || _selectedCancellationProofBytes == null
                    ? null
                    : submitPayment,
                  child: _sendingCancellationProof
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ya realice el pago'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildQrImage(String qrUrl) {
    if (qrUrl.startsWith('data:image')) {
      final commaIndex = qrUrl.indexOf(',');
      if (commaIndex != -1 && commaIndex + 1 < qrUrl.length) {
        final base64Data = qrUrl.substring(commaIndex + 1);
        try {
          final bytes = base64Decode(base64Data);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes, height: 220, fit: BoxFit.contain),
          );
        } catch (_) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: const Text('Formato de imagen QR inválido'),
          );
        }
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        qrUrl,
        height: 220,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          padding: const EdgeInsets.all(16),
          color: Colors.orange.shade50,
          child: const Text('No se pudo cargar la imagen QR'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Emergencias'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIncidents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _incidents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_outlined,
                          size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No tienes emergencias registradas',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/emergency-form')
                              .then((_) => _loadIncidents());
                        },
                        icon: const Icon(Icons.emergency),
                        label: const Text('Reportar Emergencia'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadIncidents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _incidents.length,
                    itemBuilder: (context, index) {
                      final incident = _incidents[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showIncidentDetailsLive(incident),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  runSpacing: 8,
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(incident.status)
                                          .withAlpha(51),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _getStatusText(incident.status),
                                        style: TextStyle(
                                          color: _getStatusColor(incident.status),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getPriorityColor(incident.priority)
                                          .withAlpha(51),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _getPriorityText(incident.priority),
                                        style: TextStyle(
                                          color: _getPriorityColor(incident.priority),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      incident.createdAt != null
                                          ? DateFormat('dd/MM/yy HH:mm')
                                              .format(incident.createdAt!)
                                          : '',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  incident.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (incident.aiSummary != null &&
                                    incident.aiSummary!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.blue.shade200),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('🤖',
                                            style: TextStyle(fontSize: 16)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            incident.aiSummary!,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.blue.shade900,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.directions_car,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      incident.vehicle != null
                                          ? '${incident.vehicle!.brand} ${incident.vehicle!.model}'
                                          : 'Vehículo',
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 14),
                                    ),
                                  ],
                                ),
                                if (incident.workshop != null) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.build,
                                          size: 16, color: Colors.grey),
                                      const SizedBox(width: 4),
                                      Text(
                                        incident.workshop!.name,
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                                if (incident.locationText != null &&
                                    incident.locationText!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            incident.locationText!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_canShowStripeButton(incident)) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _stripeLoadingPaymentId == incident.payment?.id
                                          ? null
                                          : () => _payWithStripe(incident),
                                      icon: _stripeLoadingPaymentId == incident.payment?.id
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Icon(Icons.credit_card),
                                      label: Text(
                                        _stripeLoadingPaymentId == incident.payment?.id
                                            ? 'Abriendo Stripe...'
                                            : 'Pagar con Stripe',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.indigo,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/emergency-form')
              .then((_) => _loadIncidents());
        },
        backgroundColor: Colors.red,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showIncidentDetails(Incident incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(incident.status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getStatusText(incident.status),
                          style: TextStyle(
                            color: _getStatusColor(incident.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(incident.priority).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getPriorityText(incident.priority),
                          style: TextStyle(
                            color: _getPriorityColor(incident.priority),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        incident.createdAt != null
                            ? DateFormat('dd/MM/yyyy HH:mm').format(incident.createdAt!)
                            : '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  if (incident.classification != null && incident.classification!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        incident.classification!.toUpperCase(),
                        style: TextStyle(
                          color: Colors.indigo.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                  if (incident.aiSummary != null && incident.aiSummary!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('🤖', style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 8),
                              Text(
                                'Análisis IA',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            incident.aiSummary!,
                            style: TextStyle(fontSize: 14, color: Colors.blue.shade900),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Text(
                    'Descripción',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(incident.description, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 24),
                  const Text(
                    'Vehículo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (incident.vehicle != null)
                    Text(
                      '${incident.vehicle!.brand} ${incident.vehicle!.model} ${incident.vehicle!.year}\nPlaca: ${incident.vehicle!.plate}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  if (incident.workshop != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Taller Asignado',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.build, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                incident.workshop!.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              if (incident.workshop!.address != null)
                                Text(
                                  incident.workshop!.address!,
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (incident.technician != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Técnico',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.engineering, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                incident.technician!.name,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                              if (incident.technician!.phone != null)
                                Text(
                                  incident.technician!.phone!,
                                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (incident.estimatedArrivalTime != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Llegada estimada: ${DateFormat('HH:mm').format(incident.estimatedArrivalTime!)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (incident.acceptedAt != null || incident.startedAt != null || incident.completedAt != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Seguimiento',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          if (incident.acceptedAt != null)
                            _buildTimelineItem(
                              '✅',
                              'Aceptada',
                              DateFormat('dd/MM/yyyy HH:mm').format(incident.acceptedAt!),
                            ),
                          if (incident.startedAt != null)
                            _buildTimelineItem(
                              '🔧',
                              'Iniciada',
                              DateFormat('dd/MM/yyyy HH:mm').format(incident.startedAt!),
                            ),
                          if (incident.completedAt != null)
                            _buildTimelineItem(
                              '✔️',
                              'Completada',
                              DateFormat('dd/MM/yyyy HH:mm').format(incident.completedAt!),
                              isLast: true,
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (incident.payment != null) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Pago',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Monto:',
                                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                              ),
                              Text(
                                '\$${incident.payment!.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Estado:',
                                style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: incident.payment!.status == 'paid'
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  incident.payment!.status == 'paid' ? 'Pagado' : 'Pendiente',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: incident.payment!.status == 'paid'
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_canShowStripeButton(incident)) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _stripeLoadingPaymentId == incident.payment?.id
                              ? null
                              : () => _payWithStripe(incident),
                          icon: _stripeLoadingPaymentId == incident.payment?.id
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.credit_card),
                          label: Text(
                            _stripeLoadingPaymentId == incident.payment?.id
                                ? 'Abriendo Stripe...'
                                : 'Pagar con Stripe',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                          ),
                        ),
                      ),
                    ],

                  ],
                  if (_canCancelIncident(incident)) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _cancelLoadingIncidentId == incident.id
                            ? null
                            : () => _cancelIncident(incident),
                        icon: _cancelLoadingIncidentId == incident.id
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: Text(
                          _cancelLoadingIncidentId == incident.id
                              ? 'Cancelando...'
                              : 'Cancelar servicio',
                        ),
                      ),
                    ),
                  ],
                    if (incident.id != null &&
                      (incident.status == 'pending' ||
                        incident.status == 'waiting_offers' ||
                        incident.status == 'assigned')) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EmergencyOffersScreen(incident: incident),
                            ),
                          );
                          if (!context.mounted) return;
                          if (result == true) {
                            Navigator.pop(context);
                            _loadIncidents();
                          }
                        },
                        icon: const Icon(Icons.local_offer),
                        label: const Text('Ver Ofertas de Talleres'),
                      ),
                    ),
                  ],
                  if (incident.id != null &&
                      (incident.status == 'assigned' ||
                          incident.status == 'accepted' ||
                          incident.status == 'on_route')) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => IncidentTrackingScreen(incident: incident),
                            ),
                          );
                        },
                        icon: const Icon(Icons.route),
                        label: const Text('Ver Seguimiento'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                        ),
                      ),
                    ),
                  ],
                  if (incident.id != null &&
                      (incident.status == 'in_service' ||
                          incident.status == 'in_progress')) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Text(
                        'La atención ya inició. El seguimiento en tiempo real ya no se muestra en esta etapa.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                  if (incident.locationText != null && incident.locationText!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Ubicación',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            incident.locationText!,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimelineItem(String emoji, String title, String time, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              if (!isLast)
                Container(
                  height: 30,
                  width: 2,
                  margin: const EdgeInsets.only(top: 4),
                  color: Colors.grey.shade300,
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  time,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
