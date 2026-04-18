import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class EmergencyFormScreen extends StatefulWidget {
  const EmergencyFormScreen({super.key});

  @override
  State<EmergencyFormScreen> createState() => _EmergencyFormScreenState();
}

class _EmergencyFormScreenState extends State<EmergencyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
  String _selectedPriority = 'medium';
  bool _isLoading = false;
  bool _loadingVehicles = true;
  double? _latitude;
  double? _longitude;
  bool _locationSelected = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final response = await apiService.get('/vehicles', token: authService.token);
      setState(() {
        _vehicles = (response as List).map((v) => Vehicle.fromJson(v)).toList();
        _loadingVehicles = false;
      });
    } catch (e) {
      setState(() => _loadingVehicles = false);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cargar vehículos'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permiso de ubicación denegado'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permiso de ubicación denegado permanentemente. Habilítalo en configuración.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationSelected = true;
        _locationController.text = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ubicación obtenida correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al obtener ubicación: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un vehículo'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authService = Provider.of<AuthService>(context, listen: false);
    final apiService = Provider.of<ApiService>(context, listen: false);

    try {
      final incident = Incident(
        description: _descriptionController.text.trim(),
        vehicleId: _selectedVehicle!.id,
        locationText: _locationController.text.trim(),
        latitude: _latitude ?? 0.0,
        longitude: _longitude ?? 0.0,
        priority: _selectedPriority,
      );

      await apiService.post(
        '/incidents',
        incident.toJson(),
        token: authService.token,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Emergencia reportada! Te contactaremos pronto'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar Emergencia'),
        backgroundColor: Colors.red,
      ),
      body: _loadingVehicles
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_car_outlined, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        'No tienes vehículos registrados',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/vehicle-form').then((_) => _loadVehicles());
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Registrar Vehículo'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '¿Necesitas ayuda? Completa este formulario',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Selecciona tu vehículo',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<Vehicle>(
                          value: _selectedVehicle,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            hintText: 'Elige un vehículo',
                            prefixIcon: Icon(Icons.directions_car),
                          ),
                          items: _vehicles.map((vehicle) {
                            return DropdownMenuItem(
                              value: vehicle,
                              child: Text(
                                '${vehicle.brand} ${vehicle.model} - ${vehicle.plate}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedVehicle = value);
                          },
                          validator: (value) => value == null ? 'Selecciona un vehículo' : null,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Describe la emergencia',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: 'Ej: Llanta ponchada en la autopista...',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) return 'Describe la emergencia';
                            if (value!.length < 10) return 'Mínimo 10 caracteres';
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Prioridad',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedPriority,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            hintText: 'Selecciona prioridad',
                            prefixIcon: Icon(Icons.priority_high),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'low', child: Text('🟢 Baja')),
                            DropdownMenuItem(value: 'medium', child: Text('🟡 Media')),
                            DropdownMenuItem(value: 'high', child: Text('🔴 Alta')),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedPriority = value!);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _selectedPriority == 'high'
                                ? 'Urgente'
                                : _selectedPriority == 'medium'
                                    ? 'Necesito ayuda pronto'
                                    : 'Puedo esperar',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Ubicación',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            hintText: 'Ej: Av. Principal km 15',
                            prefixIcon: Icon(Icons.location_on),
                          ),
                          validator: (value) => value?.isEmpty ?? true ? 'Indica tu ubicación' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _getCurrentLocation,
                                icon: const Icon(Icons.my_location),
                                label: const Text('Ubicación Actual'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_locationSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ubicación GPS seleccionada\nLat: ${_latitude?.toStringAsFixed(6)}, Lng: ${_longitude?.toStringAsFixed(6)}',
                                      style: const TextStyle(fontSize: 12, color: Colors.green),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.emergency),
                          label: Text(
                            _isLoading ? 'Enviando...' : 'Solicitar Ayuda',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
