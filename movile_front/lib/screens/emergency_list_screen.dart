import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

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
  Timer? _etaRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
    _etaRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
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

  void _showIncidentDetailsLive(Incident incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _IncidentDetailsSheet(initialIncident: incident),
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
}

class _IncidentDetailsSheet extends StatefulWidget {
  final Incident initialIncident;

  const _IncidentDetailsSheet({required this.initialIncident});

  @override
  State<_IncidentDetailsSheet> createState() => _IncidentDetailsSheetState();
}

class _IncidentDetailsSheetState extends State<_IncidentDetailsSheet> {
  late Incident _incident;
  Timer? _refreshTimer;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _incident = widget.initialIncident;
    _refreshIncident();
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        _refreshIncident();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshIncident() async {
    if (_loading || _incident.id == null) return;
    _loading = true;
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final apiService = Provider.of<ApiService>(context, listen: false);
      final response = await apiService.get(
        '/incidents/${_incident.id}',
        token: authService.token,
      );
      if (!mounted) return;
      setState(() {
        _incident = Incident.fromJson(response as Map<String, dynamic>);
      });
    } catch (_) {
      // Mantener la última información disponible.
    } finally {
      _loading = false;
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

  String _formatRemainingEta(DateTime eta) {
    final remaining = eta.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return 'llegó';
    if (remaining.inSeconds < 60) return 'en ${remaining.inSeconds}s';
    if (remaining.inMinutes < 60) return 'en ${remaining.inMinutes}m';
    if (remaining.inHours < 24) return 'en ${remaining.inHours}h';
    return 'en ${remaining.inDays}d';
  }

  Widget _buildTimelineItem(String emoji, String title, String time,
      {bool isLast = false}) {
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
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
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

  @override
  Widget build(BuildContext context) {
    final incident = _incident;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.92,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(incident.status).withAlpha(51),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      incident.estimatedArrivalTime != null
                          ? 'ETA ${_formatRemainingEta(incident.estimatedArrivalTime!)}'
                          : 'ETA pendiente',
                      style: TextStyle(
                        color: Colors.green.shade700,
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
              const SizedBox(height: 20),
              const Text(
                'Descripción',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(incident.description, style: const TextStyle(fontSize: 16)),
              if (incident.status == 'waiting_offers') ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EmergencyOffersScreen(incident: incident),
                        ),
                      );
                    },
                    icon: const Icon(Icons.local_offer),
                    label: const Text('Ver ofertas'),
                  ),
                ),
              ],
              if (incident.workshop != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Taller Asignado',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
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
              if (incident.technician != null) ...[
                const SizedBox(height: 24),
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
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          if (incident.technician!.phone != null)
                            Text(
                              incident.technician!.phone!,
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.grey),
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
                      Expanded(
                        child: Text(
                          'Llegada estimada: ${DateFormat('HH:mm').format(incident.estimatedArrivalTime!)} · ${_formatRemainingEta(incident.estimatedArrivalTime!)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if ((incident.status == 'assigned' ||
                      incident.status == 'accepted' ||
                      incident.status == 'on_route' ||
                      incident.status == 'in_service') &&
                  incident.technician != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IncidentTrackingScreen(incident: incident),
                        ),
                      );
                    },
                    icon: const Icon(Icons.location_searching),
                    label: const Text('Ver seguimiento en tiempo real'),
                  ),
                ),
              ],
              if (incident.acceptedAt != null ||
                  incident.startedAt != null ||
                  incident.completedAt != null) ...[
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
                            style: TextStyle(
                                fontSize: 15, color: Colors.grey.shade700),
                          ),
                          Text(
                            '\$${incident.payment!.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Estado:',
                            style: TextStyle(
                                fontSize: 15, color: Colors.grey.shade700),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: incident.payment!.status == 'paid'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              incident.payment!.status == 'paid'
                                  ? 'Pagado'
                                  : 'Pendiente',
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
  }
}
