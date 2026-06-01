import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class EmergencyOffersScreen extends StatefulWidget {
  final Incident incident;

  const EmergencyOffersScreen({super.key, required this.incident});

  @override
  State<EmergencyOffersScreen> createState() => _EmergencyOffersScreenState();
}

class _EmergencyOffersScreenState extends State<EmergencyOffersScreen> {
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  List<Offer> _offers = [];

  @override
  void initState() {
    super.initState();
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final response = await apiService.get(
        '/incidents/${widget.incident.id}/offers',
        token: authService.token,
      );

      if (!mounted) return;
      setState(() {
        _offers = (response as List)
            .map((item) => Offer.fromJson(item as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las ofertas: $e';
        _loading = false;
      });
    }
  }

  Future<void> _acceptOffer(Offer offer) async {
    if (_submitting) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await apiService.post(
        '/offers/${offer.id}/accept',
        {},
        token: authService.token,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oferta aceptada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'No se pudo aceptar la oferta: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ofertas de Talleres')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadOffers,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_error!,
                          style: TextStyle(color: Colors.red.shade700)),
                    ),
                  ],
                  if (_offers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Aun no hay ofertas para esta emergencia.\nDesliza hacia abajo para actualizar.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ..._offers.map((offer) {
                    final workshopName =
                        offer.workshop?.name ?? 'Taller #${offer.workshopId}';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    workshopName,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: offer.status == 'pending'
                                        ? Colors.orange.shade100
                                        : (offer.status == 'accepted'
                                            ? Colors.green.shade100
                                            : Colors.grey.shade200),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    offer.status,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Monto: \$${offer.amount.toStringAsFixed(2)}'),
                            if (offer.estimatedArrivalTime != null)
                              Text(
                                'Llegada estimada: ${offer.estimatedArrivalTime} min',
                              ),
                            if (offer.technician != null)
                              Text('Tecnico: ${offer.technician!.name}'),
                            if (offer.notes != null &&
                                offer.notes!.trim().isNotEmpty)
                              Text('Notas: ${offer.notes}'),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed:
                                    (_submitting || offer.status != 'pending')
                                        ? null
                                        : () => _acceptOffer(offer),
                                child: Text(
                                  _submitting
                                      ? 'Procesando...'
                                      : 'Seleccionar oferta',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}
