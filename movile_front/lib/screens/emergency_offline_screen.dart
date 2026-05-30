import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/offline_emergency.dart';
import '../services/offline_emergency_storage_service.dart';

class EmergencyOfflineScreen extends StatefulWidget {
  const EmergencyOfflineScreen({super.key});

  @override
  State<EmergencyOfflineScreen> createState() => _EmergencyOfflineScreenState();
}

class _EmergencyOfflineScreenState extends State<EmergencyOfflineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storageService = OfflineEmergencyStorageService();

  final _clientEmailController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _incidentTypeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  OfflineEmergency? _activeEmergency;
  bool _isEditing = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadActiveEmergency();
  }

  @override
  void dispose() {
    _clientEmailController.dispose();
    _clientPhoneController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehiclePlateController.dispose();
    _incidentTypeController.dispose();
    _descriptionController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveEmergency() async {
    final emergency = await _storageService.getActiveEmergency();
    if (!mounted) return;
    setState(() {
      _activeEmergency = emergency;
      _loading = false;
      _isEditing = false;
    });
  }

  bool _isActiveStatus(String status) {
    return status == 'pending' || status == 'syncing' || status == 'failed';
  }

  void _populateForm(OfflineEmergency emergency) {
    _clientEmailController.text = emergency.clientEmail;
    _clientPhoneController.text = emergency.clientPhone ?? '';
    _vehicleBrandController.text = emergency.vehicleBrand;
    _vehicleModelController.text = emergency.vehicleModel;
    _vehicleYearController.text = emergency.vehicleYear.toString();
    _vehiclePlateController.text = emergency.vehiclePlate;
    _incidentTypeController.text = emergency.incidentType;
    _descriptionController.text = emergency.description;
    _addressController.text = emergency.address;
    _latitudeController.text = emergency.latitude?.toString() ?? '';
    _longitudeController.text = emergency.longitude?.toString() ?? '';
  }

  void _clearForm() {
    _clientEmailController.clear();
    _clientPhoneController.clear();
    _vehicleBrandController.clear();
    _vehicleModelController.clear();
    _vehicleYearController.clear();
    _vehiclePlateController.clear();
    _incidentTypeController.clear();
    _descriptionController.clear();
    _addressController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
  }

  String? _requiredValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label es obligatorio';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Correo obligatorio';
    }
    final email = value.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Correo con formato inválido';
    }
    return null;
  }

  String? _yearValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Año obligatorio';
    }
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      return 'Año debe ser numérico';
    }
    final currentYear = DateTime.now().year;
    if (parsed < 1950 || parsed > currentYear + 1) {
      return 'Año fuera de rango válido';
    }
    return null;
  }

  String? _optionalDoubleValidator(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return '$label debe ser numérico';
    }
    return null;
  }

  String _generateLocalId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'local_${now}_$random';
  }

  String _generateClientOfflineId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999).toString().padLeft(6, '0');
    return 'offline_${now}_$random';
  }

  Future<void> _handleSaveOffline() async {
    if (!_formKey.currentState!.validate()) return;

    final hasActive = await _storageService.hasActiveEmergency();
    if (!_isEditing && hasActive) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ya tienes una emergencia offline pendiente. Puedes editarla o eliminarla antes de crear otra.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      await _loadActiveEmergency();
      return;
    }

    final year = int.parse(_vehicleYearController.text.trim());
    final lat = _latitudeController.text.trim().isEmpty
        ? null
        : double.tryParse(_latitudeController.text.trim());
    final lng = _longitudeController.text.trim().isEmpty
        ? null
        : double.tryParse(_longitudeController.text.trim());

    if (_isEditing && _activeEmergency != null) {
      final updated = _activeEmergency!.copyWith(
        clientEmail: _clientEmailController.text.trim(),
        clientPhone: _clientPhoneController.text.trim().isEmpty
            ? null
            : _clientPhoneController.text.trim(),
        vehicleBrand: _vehicleBrandController.text.trim(),
        vehicleModel: _vehicleModelController.text.trim(),
        vehicleYear: year,
        vehiclePlate: _vehiclePlateController.text.trim().toUpperCase(),
        incidentType: _incidentTypeController.text.trim(),
        description: _descriptionController.text.trim(),
        address: _addressController.text.trim(),
        latitude: lat,
        longitude: lng,
      );

      await _storageService.updateEmergency(updated);
      if (!mounted) return;
      setState(() {
        _activeEmergency = updated;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emergencia offline actualizada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final created = OfflineEmergency(
      localId: _generateLocalId(),
      clientOfflineId: _generateClientOfflineId(),
      clientEmail: _clientEmailController.text.trim(),
      clientPhone: _clientPhoneController.text.trim().isEmpty
          ? null
          : _clientPhoneController.text.trim(),
      vehicleBrand: _vehicleBrandController.text.trim(),
      vehicleModel: _vehicleModelController.text.trim(),
      vehicleYear: year,
      vehiclePlate: _vehiclePlateController.text.trim().toUpperCase(),
      incidentType: _incidentTypeController.text.trim(),
      description: _descriptionController.text.trim(),
      address: _addressController.text.trim(),
      latitude: lat,
      longitude: lng,
      createdOfflineAt: DateTime.now().toUtc(),
      syncStatus: 'pending',
      syncAttempts: 0,
      lastError: null,
      backendIncidentId: null,
      syncedAt: null,
    );

    await _storageService.saveEmergency(created);
    if (!mounted) return;
    setState(() {
      _activeEmergency = created;
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Emergencia guardada localmente. Podrás sincronizarla cuando vuelva internet.',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _captureCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('location_service_disabled');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('location_permission_denied');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latitudeController.text = position.latitude.toStringAsFixed(6);
      _longitudeController.text = position.longitude.toStringAsFixed(6);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ubicación capturada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo obtener la ubicación. Puedes ingresar latitud y longitud manualmente.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteEmergencyLocal() async {
    await _storageService.deleteEmergency();
    if (!mounted) return;
    setState(() {
      _activeEmergency = null;
      _isEditing = false;
    });
    _clearForm();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emergencia offline eliminada localmente.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildActiveEmergencyCard(OfflineEmergency emergency) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergencia offline pendiente',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Correo: ${emergency.clientEmail}'),
            Text('Vehículo: ${emergency.vehicleBrand} ${emergency.vehicleModel}'),
            Text('Placa: ${emergency.vehiclePlate}'),
            Text('Descripción: ${emergency.description}'),
            Text('Dirección: ${emergency.address}'),
            if (emergency.latitude != null && emergency.longitude != null)
              Text('Lat/Lng: ${emergency.latitude}, ${emergency.longitude}'),
            Text('Estado: ${emergency.syncStatus}'),
            Text(
              'Creada: ${DateFormat('dd/MM/yyyy HH:mm').format(emergency.createdOfflineAt.toLocal())}',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _populateForm(emergency);
                      setState(() => _isEditing = true);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar emergencia'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _deleteEmergencyLocal,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar emergencia local'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.sync_outlined),
                    label: const Text('La sincronización se implementará en la siguiente fase'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: const Text(
              'Puedes registrar una emergencia sin conexión. Se guardará en este dispositivo y podrás sincronizarla cuando vuelva internet.',
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: const Text(
              'Debes usar el correo de tu cuenta registrada en AUTOGO.',
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _clientEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Correo registrado del cliente',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: _emailValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _clientPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono (opcional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _vehicleBrandController,
            decoration: const InputDecoration(
              labelText: 'Marca del vehículo',
              prefixIcon: Icon(Icons.directions_car_outlined),
            ),
            validator: (v) => _requiredValidator(v, 'Marca'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _vehicleModelController,
            decoration: const InputDecoration(
              labelText: 'Modelo del vehículo',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
            validator: (v) => _requiredValidator(v, 'Modelo'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _vehicleYearController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Año del vehículo',
              hintText: DateFormat('yyyy').format(DateTime.now()),
              prefixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            validator: _yearValidator,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _vehiclePlateController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Placa del vehículo',
              prefixIcon: Icon(Icons.confirmation_number_outlined),
            ),
            validator: (v) => _requiredValidator(v, 'Placa'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _incidentTypeController,
            decoration: const InputDecoration(
              labelText: 'Tipo de emergencia',
              prefixIcon: Icon(Icons.warning_amber_outlined),
            ),
            validator: (v) => _requiredValidator(v, 'Tipo de emergencia'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.description_outlined),
            ),
            validator: (v) => _requiredValidator(v, 'Descripción'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Dirección',
              alignLabelWithHint: true,
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            validator: (v) => _requiredValidator(v, 'Dirección'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _latitudeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(
              labelText: 'Latitud (opcional)',
              prefixIcon: Icon(Icons.my_location_outlined),
            ),
            validator: (v) => _optionalDoubleValidator(v, 'Latitud'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _longitudeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: const InputDecoration(
              labelText: 'Longitud (opcional)',
              prefixIcon: Icon(Icons.explore_outlined),
            ),
            validator: (v) => _optionalDoubleValidator(v, 'Longitud'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _captureCurrentLocation,
            icon: const Icon(Icons.my_location_outlined),
            label: const Text('Usar mi ubicación actual'),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _handleSaveOffline,
            icon: const Icon(Icons.save_outlined),
            label: Text(_isEditing
                ? 'Actualizar emergencia offline'
                : 'Guardar emergencia offline'),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _isEditing = false);
                _clearForm();
              },
              icon: const Icon(Icons.close_outlined),
              label: const Text('Cancelar edición'),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_outlined),
            label: const Text('Volver al login'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showActiveBlock = !_isEditing &&
        _activeEmergency != null &&
        _isActiveStatus(_activeEmergency!.syncStatus);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergencia offline'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showActiveBlock) _buildActiveEmergencyCard(_activeEmergency!),
                  if (!showActiveBlock) _buildForm(),
                ],
              ),
            ),
    );
  }
}
