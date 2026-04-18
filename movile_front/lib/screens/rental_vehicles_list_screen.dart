import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/rental_vehicles_service.dart';

class RentalVehiclesListScreen extends StatefulWidget {
  const RentalVehiclesListScreen({super.key});

  @override
  State<RentalVehiclesListScreen> createState() =>
      _RentalVehiclesListScreenState();
}

class _RentalVehiclesListScreenState extends State<RentalVehiclesListScreen> {
  late RentalVehiclesService _rentalVehiclesService;
  late Future<List<RentalVehicle>> _vehiclesFuture;

  @override
  void initState() {
    super.initState();
    _rentalVehiclesService = RentalVehiclesService();
    final authService = Provider.of<AuthService>(context, listen: false);
    _vehiclesFuture =
        _rentalVehiclesService.getRentalVehicles(token: authService.token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rentar Auto'),
        backgroundColor: const Color(0xFF3B82F6),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
          ),
        ),
        child: FutureBuilder<List<RentalVehicle>>(
          future: _vehiclesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.white70),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          final authService =
                              Provider.of<AuthService>(context, listen: false);
                          _vehiclesFuture =
                              _rentalVehiclesService.getRentalVehicles(
                                  token: authService.token);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                      ),
                      child: const Text('Reintentar'),
                    )
                  ],
                ),
              );
            }

            final vehicles = snapshot.data ?? [];

            if (vehicles.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_car_outlined,
                        size: 64, color: Colors.white70),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay vehículos disponibles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return _RentalVehicleCard(
                  vehicle: vehicle,
                  onViewDetails: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RentalVehicleDetailScreen(
                          vehicle: vehicle,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _RentalVehicleCard extends StatelessWidget {
  final RentalVehicle vehicle;
  final VoidCallback onViewDetails;

  const _RentalVehicleCard({
    required this.vehicle,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onViewDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vehicle Image
            if (vehicle.photoUrl != null && vehicle.photoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: Image.network(
                  vehicle.photoUrl!,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.directions_car,
                          size: 80, color: Colors.grey),
                    );
                  },
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: const Icon(Icons.directions_car,
                    size: 80, color: Colors.grey),
              ),
            // Vehicle Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.vehicleName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          vehicle.vehicleType == 'automovil'
                              ? 'Automóvil'
                              : 'Camioneta',
                          style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'De ${vehicle.companyName}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: onViewDetails,
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        label: const Text('Ver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RentalVehicleDetailScreen extends StatelessWidget {
  final RentalVehicle vehicle;

  const RentalVehicleDetailScreen({
    super.key,
    required this.vehicle,
  });

  Future<void> _launchWhatsApp(String phoneNumber) async {
    final cleaned = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('No se pudo abrir WhatsApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del Vehículo'),
        backgroundColor: const Color(0xFF3B82F6),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Vehicle Image
              if (vehicle.photoUrl != null && vehicle.photoUrl!.isNotEmpty)
                Image.network(
                  vehicle.photoUrl!,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 300,
                      color: Colors.grey[300],
                      child: const Icon(Icons.directions_car,
                          size: 100, color: Colors.grey),
                    );
                  },
                )
              else
                Container(
                  height: 300,
                  color: Colors.grey[300],
                  child: const Icon(Icons.directions_car,
                      size: 100, color: Colors.grey),
                ),
              // Details Card
              Transform.translate(
                offset: const Offset(0, -30),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Vehicle Name
                      Text(
                        vehicle.vehicleName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Vehicle Type
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              vehicle.vehicleType == 'automovil'
                                  ? 'Automóvil'
                                  : 'Camioneta',
                              style: const TextStyle(
                                color: Color(0xFF3B82F6),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Company Name
                      _DetailItem(
                        label: 'Arrendatario',
                        value: vehicle.companyName,
                        icon: Icons.business,
                      ),
                      const SizedBox(height: 16),
                      // Characteristics
                      _DetailItem(
                        label: 'Características',
                        value: vehicle.characteristics,
                        icon: Icons.info,
                        isMultiline: true,
                      ),
                      const SizedBox(height: 24),
                      // WhatsApp Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final phoneNumber = vehicle.whatsappNumber;
                            try {
                              await _launchWhatsApp(phoneNumber);
                            } catch (_) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('No se pudo abrir WhatsApp'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.chat),
                          label: const Text('WhatsApp',
                              style: TextStyle(fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Display WhatsApp Number
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, color: Color(0xFF25D366)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                vehicle.whatsappNumber,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2C3E50),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isMultiline;

  const _DetailItem({
    required this.label,
    required this.value,
    required this.icon,
    this.isMultiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF3B82F6), size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF2C3E50),
            fontWeight: FontWeight.w500,
          ),
          maxLines: isMultiline ? null : 1,
          overflow: isMultiline ? null : TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
