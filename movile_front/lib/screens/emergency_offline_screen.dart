import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class EmergencyOfflineScreen extends StatefulWidget {
  const EmergencyOfflineScreen({super.key});

  @override
  State<EmergencyOfflineScreen> createState() => _EmergencyOfflineScreenState();
}

class _EmergencyOfflineScreenState extends State<EmergencyOfflineScreen> {
  final _formKey = GlobalKey<FormState>();

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

  void _handleSaveOffline() {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Formulario offline listo. El guardado local se implementará en la siguiente fase.',
        ),
        backgroundColor: Colors.blue,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergencia offline'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
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
                label: const Text('Guardar emergencia offline'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_outlined),
                label: const Text('Volver al login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
