import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'vehicle_form_screen.dart';

class VehicleManagementScreen extends StatefulWidget {
  const VehicleManagementScreen({super.key});

  @override
  State<VehicleManagementScreen> createState() => _VehicleManagementScreenState();
}

class _VehicleManagementScreenState extends State<VehicleManagementScreen> {
  bool _isLoading = true;
  List<Vehicle> _vehicles = [];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final response = await apiService.get('/vehicles', token: authService.token);
      final items = (response as List)
          .map((item) => Vehicle.fromJson(item as Map<String, dynamic>))
          .toList();
      if (!mounted) return;
      setState(() {
        _vehicles = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando vehículos: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openCreateVehicle() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const VehicleFormScreen()),
    );
    if (result == true) {
      _loadVehicles();
    }
  }

  Future<void> _openEditVehicle(Vehicle vehicle) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VehicleFormScreen(initialVehicle: vehicle)),
    );
    if (result == true) {
      _loadVehicles();
    }
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar vehículo'),
        content: Text('¿Deseas eliminar ${vehicle.brand} ${vehicle.model}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      await apiService.delete('/vehicles/${vehicle.id}', token: authService.token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehículo eliminado'), backgroundColor: Colors.green),
      );
      _loadVehicles();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Vehículos')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('Aún no tienes vehículos registrados'),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _openCreateVehicle,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar vehículo'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVehicles,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = _vehicles[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${vehicle.brand} ${vehicle.model}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text('Año: ${vehicle.year}'),
                              Text('Placa: ${vehicle.plate}'),
                              Text('Color: ${vehicle.color?.isNotEmpty == true ? vehicle.color : 'No especificado'}'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _openEditVehicle(vehicle),
                                      icon: const Icon(Icons.edit),
                                      label: const Text('Editar'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                      onPressed: () => _deleteVehicle(vehicle),
                                      icon: const Icon(Icons.delete),
                                      label: const Text('Eliminar'),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateVehicle,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }
}
