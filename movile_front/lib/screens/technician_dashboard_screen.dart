import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../services/technician_access_service.dart';

class TechnicianDashboardScreen extends StatefulWidget {
  const TechnicianDashboardScreen({super.key});

  @override
  State<TechnicianDashboardScreen> createState() =>
      _TechnicianDashboardScreenState();
}

class _TechnicianDashboardScreenState extends State<TechnicianDashboardScreen> {
  bool _loading = true;
  String? _error;
  List<Incident> _incidents = [];
  Timer? _locationTimer;
  bool _sendingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final service = Provider.of<TechnicianAccessService>(context, listen: false);

    try {
      final incidents = await service.getIncidents();
      if (!mounted) return;
      setState(() {
        _incidents = incidents;
        _loading = false;
      });
      _syncLocationTracking();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar asignaciones: $e';
        _loading = false;
      });
    }
  }

  Incident? get _activeIncident {
    for (final incident in _incidents) {
      if (incident.status == 'accepted' ||
          incident.status == 'assigned' ||
          incident.status == 'on_route' ||
          incident.status == 'in_service' ||
          incident.status == 'in_progress') {
        return incident;
      }
    }
    return _incidents.isNotEmpty ? _incidents.first : null;
  }

  bool get _isTrackingIncident {
    final active = _activeIncident;
    return active != null && active.status == 'on_route';
  }

  void _syncLocationTracking() {
    if (_isTrackingIncident) {
      _startLocationTracking();
    } else {
      _stopLocationTracking();
    }
  }

  @override
  void dispose() {
    _stopLocationTracking();
    super.dispose();
  }

  void _startLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _sendCurrentLocation();
    });
    _sendCurrentLocation();
  }

  void _stopLocationTracking() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  Future<Position?> _getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Los servicios de ubicación están desactivados');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado');
    }

    return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _sendCurrentLocation({bool showFeedback = false}) async {
    if (_sendingLocation || !_isTrackingIncident) {
      if (showFeedback) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(const SnackBar(
            content: Text('No hay tracking activo o ya se está enviando')));
      }
      return;
    }

    final active = _activeIncident;
    if (active == null) {
      if (showFeedback) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
            const SnackBar(content: Text('No hay incidente activo')));
      }
      return;
    }

    _sendingLocation = true;
    // Capture context-related objects before any `await` to avoid
    // `use_build_context_synchronously` lints.
    final messenger = ScaffoldMessenger.of(context);
    final service =
        Provider.of<TechnicianAccessService>(context, listen: false);

    try {
      final position = await _getCurrentPosition();
      if (position == null) {
        if (showFeedback) {
          messenger.showSnackBar(
              const SnackBar(content: Text('No se pudo obtener la ubicación')));
        }
        return;
      }
      final resp = await service.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      // Log for debugging: qué coordenadas obtuvo el dispositivo y qué respondió el backend
      debugPrint('DEBUG: Sent location -> ${position.latitude}, ${position.longitude}');
      debugPrint('DEBUG: Backend response -> $resp');
      if (!mounted) return;
      setState(() {});
      if (showFeedback) {
        messenger.showSnackBar(SnackBar(
            content: Text('Ubicación enviada: ${position.latitude}, ${position.longitude}')));
      }
    } catch (e) {
      if (showFeedback) {
        messenger.showSnackBar(
            SnackBar(content: Text('Error enviando ubicación: $e')));
      }
    } finally {
      _sendingLocation = false;
    }
  }

  Widget _buildQrImage(String qrUrl) {
    if (qrUrl.startsWith('data:image')) {
      final commaIndex = qrUrl.indexOf(',');
      if (commaIndex != -1 && commaIndex + 1 < qrUrl.length) {
        final base64Data = qrUrl.substring(commaIndex + 1);
        try {
          final bytes = base64Decode(base64Data);
          return Image.memory(bytes, fit: BoxFit.contain);
        } catch (_) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange.shade50,
            child: const Text('Formato de imagen QR inválido'),
          );
        }
      }
    }

    return Image.network(
      qrUrl,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        padding: const EdgeInsets.all(16),
        color: Colors.orange.shade50,
        child: const Text('No se pudo cargar la imagen QR'),
      ),
    );
  }

  Future<void> _updateStatus(Incident incident, String newStatus) async {
    final messenger = ScaffoldMessenger.of(context);
    final service =
        Provider.of<TechnicianAccessService>(context, listen: false);

    try {
      await service.updateIncidentStatus(incident.id!, newStatus);
      if (!mounted) return;
      await _loadIncidents();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('Estado actualizado a $newStatus'),
            backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('No se pudo actualizar estado: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _confirmPayment(Incident incident) async {
    final messenger = ScaffoldMessenger.of(context);
    final service =
        Provider.of<TechnicianAccessService>(context, listen: false);
    final method = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.payments),
                title: const Text('Confirmar pago en efectivo'),
                onTap: () => Navigator.pop(context, 'cash'),
              ),
              ListTile(
                leading: const Icon(Icons.qr_code_2),
                title: const Text('Confirmar pago por QR'),
                onTap: () => Navigator.pop(context, 'qr'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted) return;
    if (method == null) return;
    try {
      if (method == 'qr') {
        final shouldContinue =
            await _showQrPaymentDialog(incident.id!, service);
        if (!mounted || !shouldContinue) return;
      }

      await service.confirmPayment(
          incidentId: incident.id!, paymentMethod: method);
      if (!mounted) return;
      await _loadIncidents();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Pago confirmado'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('No se pudo confirmar pago: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> _showQrPaymentDialog(
      int incidentId, TechnicianAccessService service) async {
    final messenger = ScaffoldMessenger.of(context);
    String qrUrl = '';

    try {
      qrUrl = await service.getIncidentPaymentQrUrl(incidentId);
    } catch (e) {
      if (!mounted) return false;
      messenger.showSnackBar(
        SnackBar(
            content: Text('No se pudo obtener el QR del taller: $e'),
            backgroundColor: Colors.red),
      );
      return false;
    }

    if (!mounted) return false;
    if (qrUrl.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('El taller no tiene QR configurado'),
            backgroundColor: Colors.orange),
      );
      return false;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cobro por QR'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Muestra esta imagen al cliente para escanear y pagar:'),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildQrImage(qrUrl),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Cliente pagó, confirmar'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _openLocation(Incident incident) async {
    final messenger = ScaffoldMessenger.of(context);
    final lat = incident.latitude;
    final lng = incident.longitude;

    if (lat == null || lng == null) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Ubicación no disponible'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    final url = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        const SnackBar(
            content: Text('No se pudo abrir Google Maps'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _logout() async {
    final navigator = Navigator.of(context);
    final service =
        Provider.of<TechnicianAccessService>(context, listen: false);
    await service.logout();
    if (!mounted) return;
    navigator.pushReplacementNamed('/technician/access');
  }

  @override
  Widget build(BuildContext context) {
    final service = Provider.of<TechnicianAccessService>(context);
    final active = _activeIncident;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Mecánico'),
        actions: [
          IconButton(
            onPressed: _loadIncidents,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadIncidents,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mecánico: ${service.technicianName ?? '-'}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Taller: ${service.workshopName ?? '-'}'),
                          if (_isTrackingIncident) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Tracking activo en tiempo real',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_error!,
                          style: TextStyle(color: Colors.red.shade700)),
                    ),
                  const SizedBox(height: 12),
                  if (active == null)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                            'No tienes emergencias asignadas actualmente.'),
                      ),
                    )
                  else
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Emergencia #${active.id}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18)),
                            const SizedBox(height: 8),
                            Text('Estado: ${active.status}'),
                            Text('Prioridad: ${active.priority}'),
                            Text('Descripción: ${active.description}'),
                            if (active.remainingDistanceMeters != null)
                              Text(
                                  'Distancia restante: ${active.remainingDistanceMeters} m'),
                            if (active.estimatedArrivalTime != null)
                              Text(
                                  'ETA: ${DateFormat('HH:mm').format(active.estimatedArrivalTime!)}'),
                            if (active.user != null)
                              Text('Cliente: ${active.user!.fullName}'),
                            if (active.locationText != null)
                              Text('Ubicación: ${active.locationText}'),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: (active.latitude != null &&
                                        active.longitude != null)
                                    ? () => _openLocation(active)
                                    : null,
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Ir a ubicación del cliente'),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: (active.status == 'assigned' ||
                                            active.status == 'accepted')
                                        ? () =>
                                            _updateStatus(active, 'on_route')
                                        : null,
                                    icon: const Icon(Icons.alt_route),
                                    label: const Text('Iniciar recorrido'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: active.status == 'on_route'
                                        ? () =>
                                            _updateStatus(active, 'in_service')
                                        : null,
                                    icon: const Icon(Icons.play_circle),
                                    label: const Text('Iniciar atención'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: active.status == 'in_service'
                                        ? () =>
                                            _updateStatus(active, 'completed')
                                        : null,
                                    icon:
                                        const Icon(Icons.check_circle_outline),
                                    label: const Text('Finalizar servicio'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: active.status == 'in_service' ||
                                            active.status == 'on_route'
                                        ? () =>
                                            _updateStatus(active, 'cancelled')
                                        : null,
                                    icon: const Icon(Icons.cancel_outlined),
                                    label: const Text(
                                        'Cancelar / No pude atender'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (active.status == 'completed')
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _confirmPayment(active),
                                      icon: const Icon(Icons.payments_outlined),
                                      label: const Text('Confirmar pago'),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
