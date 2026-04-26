import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../models/models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// State machine steps
// ─────────────────────────────────────────────────────────────────────────────
enum _Step { audio, image, review, submitting }

class EmergencyFormScreen extends StatefulWidget {
  const EmergencyFormScreen({super.key});

  @override
  State<EmergencyFormScreen> createState() => _EmergencyFormScreenState();
}

class _EmergencyFormScreenState extends State<EmergencyFormScreen> {
  // ── Wizard state ──────────────────────────────────────────────────────────
  _Step _step = _Step.audio;

  // ── Audio ─────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  String? _audioPath;
  bool _processingAudio = false;
  String _audioDescription = '';

  // ── Image ─────────────────────────────────────────────────────────────────
  File? _imageFile;
  bool _processingImage = false;
  String _imageDescription = '';

  // ── Review ────────────────────────────────────────────────────────────────
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  String _priority = 'medium';
  List<Vehicle> _vehicles = [];
  Vehicle? _selectedVehicle;
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
    _recorder.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────
  Future<void> _loadVehicles() async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    try {
      final response = await api.get('/vehicles', token: auth.token);
      setState(() {
        _vehicles = (response as List).map((v) => Vehicle.fromJson(v)).toList();
        _loadingVehicles = false;
      });
    } catch (_) {
      setState(() => _loadingVehicles = false);
    }
  }

  // ── Audio recording ───────────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _recorder.stop();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showError('Permiso de micrófono requerido');
        return;
      }
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/emergency_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 16000),
        path: filePath,
      );
      setState(() => _isRecording = true);
    }
  }

  Future<void> _analyzeAudio() async {
    if (_audioPath == null) return;
    setState(() => _processingAudio = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    try {
      final result = await api.postMultipart(
        '/ai/analyze-audio',
        'audio',
        _audioPath!,
        'audio/mp4',
        token: auth.token,
      );
      setState(() {
        _audioDescription = result['description'] ?? '';
        _priority = result['priority'] ?? 'medium';
        _processingAudio = false;
      });
    } catch (e) {
      setState(() => _processingAudio = false);
      _showError('Error al analizar audio: $e');
    }
  }

  // ── Image capture ─────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1280);
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  Future<void> _analyzeImage() async {
    if (_imageFile == null) return;
    setState(() => _processingImage = true);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final mime = _imageFile!.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    try {
      final result = await api.postMultipart(
        '/ai/analyze-image',
        'image',
        _imageFile!.path,
        mime,
        token: auth.token,
      );
      setState(() {
        _imageDescription = result['description'] ?? '';
        _processingImage = false;
      });
    } catch (e) {
      setState(() => _processingImage = false);
      _showError('Error al analizar imagen: $e');
    }
  }

  // ── Location ──────────────────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _showError('Permiso de ubicación denegado');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
        _locationSelected = true;
        _locationController.text =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      });
    } catch (e) {
      _showError('Error al obtener ubicación: $e');
    }
  }

  // ── Final submit ──────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (_selectedVehicle == null) {
      _showError('Selecciona un vehículo');
      return;
    }
    setState(() => _step = _Step.submitting);
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();

    // Build combined description
    final parts = <String>[];
    if (_descController.text.trim().isNotEmpty) parts.add(_descController.text.trim());
    if (_audioDescription.isNotEmpty && !parts.contains(_audioDescription)) {
      parts.add(_audioDescription);
    }
    final finalDesc = parts.join('\n\n').trim();

    String? imageDataUrl;
    if (_imageFile != null) {
      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);
      final lowerPath = _imageFile!.path.toLowerCase();
      final mime = lowerPath.endsWith('.png') ? 'image/png' : 'image/jpeg';
      imageDataUrl = 'data:$mime;base64,$base64Image';
    }

    try {
      await api.post(
        '/incidents',
        {
          'description': finalDesc.isEmpty ? 'Emergencia vehicular' : finalDesc,
          'vehicle_id': _selectedVehicle!.id,
          'location_text': _locationController.text.trim(),
          'latitude': _latitude ?? 0.0,
          'longitude': _longitude ?? 0.0,
          'image_url': imageDataUrl,
          'priority': _priority,
          'ai_summary': _imageDescription.isEmpty ? null : _imageDescription,
        },
        token: auth.token,
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
      setState(() => _step = _Step.review);
      _showError('Error al enviar: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void _goToReview() {
    // Merge descriptions into the text controller if it's empty
    final parts = [_audioDescription, _imageDescription].where((s) => s.isNotEmpty).toList();
    if (_descController.text.trim().isEmpty && parts.isNotEmpty) {
      _descController.text = parts.join('\n\n');
    }
    setState(() => _step = _Step.review);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportar Emergencia'),
        backgroundColor: Colors.red,
        actions: [
          if (_step == _Step.audio || _step == _Step.image)
            TextButton(
              onPressed: _goToReview,
              child: const Text('Saltar', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.audio:
        return _AudioStep(
          key: const ValueKey('audio'),
          isRecording: _isRecording,
          audioPath: _audioPath,
          isProcessing: _processingAudio,
          description: _audioDescription,
          onToggleRecord: _toggleRecording,
          onAnalyze: _analyzeAudio,
          onNext: () => setState(() => _step = _Step.image),
          onSkip: () => setState(() => _step = _Step.image),
        );
      case _Step.image:
        return _ImageStep(
          key: const ValueKey('image'),
          imageFile: _imageFile,
          isProcessing: _processingImage,
          description: _imageDescription,
          onPickImage: _pickImage,
          onAnalyze: _analyzeImage,
          onNext: _goToReview,
          onSkip: _goToReview,
        );
      case _Step.review:
        return _ReviewStep(
          key: const ValueKey('review'),
          descController: _descController,
          locationController: _locationController,
          vehicles: _vehicles,
          loadingVehicles: _loadingVehicles,
          selectedVehicle: _selectedVehicle,
          priority: _priority,
          locationSelected: _locationSelected,
          latitude: _latitude,
          longitude: _longitude,
          audioDescription: _audioDescription,
          imageDescription: _imageDescription,
          onVehicleChanged: (v) => setState(() => _selectedVehicle = v),
          onPriorityChanged: (p) => setState(() => _priority = p),
          onGetLocation: _getCurrentLocation,
          onSubmit: _submit,
        );
      case _Step.submitting:
        return const Center(
          key: ValueKey('submitting'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red),
              SizedBox(height: 16),
              Text('Enviando emergencia…', style: TextStyle(fontSize: 16)),
            ],
          ),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — Audio
// ─────────────────────────────────────────────────────────────────────────────
class _AudioStep extends StatelessWidget {
  final bool isRecording;
  final String? audioPath;
  final bool isProcessing;
  final String description;
  final VoidCallback onToggleRecord;
  final VoidCallback onAnalyze;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _AudioStep({
    super.key,
    required this.isRecording,
    required this.audioPath,
    required this.isProcessing,
    required this.description,
    required this.onToggleRecord,
    required this.onAnalyze,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress indicator
          _WizardProgress(step: 1, total: 3),
          const SizedBox(height: 24),
          const Text(
            'Describe la emergencia por voz',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Presiona el micrófono, describe tu problema, luego analiza con IA.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: onToggleRecord,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isRecording ? Colors.red.shade700 : Colors.red,
                  boxShadow: isRecording
                      ? [BoxShadow(color: Colors.red.shade300, blurRadius: 20, spreadRadius: 6)]
                      : [],
                ),
                child: Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  size: 52,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              isRecording ? 'Grabando… toca para detener' : audioPath != null ? 'Grabación lista' : 'Toca para grabar',
              style: TextStyle(
                color: isRecording ? Colors.red : Colors.grey.shade600,
                fontWeight: isRecording ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (audioPath != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: isProcessing ? null : onAnalyze,
              icon: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(isProcessing ? 'Analizando con IA…' : 'Analizar con IA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: Colors.indigo),
                      SizedBox(width: 6),
                      Text('Transcripción IA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(description),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  child: const Text('Omitir audio'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (audioPath != null || description.isNotEmpty) ? onNext : null,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Siguiente'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — Image
// ─────────────────────────────────────────────────────────────────────────────
class _ImageStep extends StatelessWidget {
  final File? imageFile;
  final bool isProcessing;
  final String description;
  final void Function(ImageSource) onPickImage;
  final VoidCallback onAnalyze;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _ImageStep({
    super.key,
    required this.imageFile,
    required this.isProcessing,
    required this.description,
    required this.onPickImage,
    required this.onAnalyze,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WizardProgress(step: 2, total: 3),
          const SizedBox(height: 24),
          const Text(
            'Foto de la emergencia',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Toma o elige una foto del problema para análisis automático.',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (imageFile != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(imageFile!, height: 220, fit: BoxFit.cover),
            )
          else
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Sin foto', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onPickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Cámara'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onPickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
          if (imageFile != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: isProcessing ? null : onAnalyze,
              icon: isProcessing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(isProcessing ? 'Analizando imagen…' : 'Analizar con IA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18, color: Colors.indigo),
                      SizedBox(width: 6),
                      Text('Análisis IA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(description),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSkip,
                  child: const Text('Omitir foto'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Siguiente'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — Review & Submit
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewStep extends StatelessWidget {
  final TextEditingController descController;
  final TextEditingController locationController;
  final List<Vehicle> vehicles;
  final bool loadingVehicles;
  final Vehicle? selectedVehicle;
  final String priority;
  final bool locationSelected;
  final double? latitude;
  final double? longitude;
  final String audioDescription;
  final String imageDescription;
  final void Function(Vehicle?) onVehicleChanged;
  final void Function(String) onPriorityChanged;
  final VoidCallback onGetLocation;
  final VoidCallback onSubmit;

  const _ReviewStep({
    super.key,
    required this.descController,
    required this.locationController,
    required this.vehicles,
    required this.loadingVehicles,
    required this.selectedVehicle,
    required this.priority,
    required this.locationSelected,
    required this.latitude,
    required this.longitude,
    required this.audioDescription,
    required this.imageDescription,
    required this.onVehicleChanged,
    required this.onPriorityChanged,
    required this.onGetLocation,
    required this.onSubmit,
  });

  Color _priorityColor(String p) =>
      p == 'high' ? Colors.red : p == 'low' ? Colors.green : Colors.orange;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WizardProgress(step: 3, total: 3),
          const SizedBox(height: 24),
          const Text(
            'Revisa y envía',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // AI summary chips
          if (audioDescription.isNotEmpty || imageDescription.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: Colors.indigo),
                      SizedBox(width: 6),
                      Text('Análisis IA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo, fontSize: 13)),
                    ],
                  ),
                  if (audioDescription.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('🎤 $audioDescription', style: const TextStyle(fontSize: 12)),
                  ],
                  if (imageDescription.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('📷 $imageDescription', style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Editable description
          const Text('Descripción', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: descController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Describe la emergencia (editado por IA o escribe tú)',
            ),
          ),
          const SizedBox(height: 20),

          // Priority
          const Text('Prioridad detectada', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            value: priority,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.priority_high, color: _priorityColor(priority)),
            ),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('🟢 Baja')),
              DropdownMenuItem(value: 'medium', child: Text('🟡 Media')),
              DropdownMenuItem(value: 'high', child: Text('🔴 Alta')),
            ],
            onChanged: (v) => onPriorityChanged(v!),
          ),
          const SizedBox(height: 20),

          // Vehicle
          const Text('Vehículo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          loadingVehicles
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<Vehicle>(
                  value: selectedVehicle,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Selecciona tu vehículo',
                    prefixIcon: Icon(Icons.directions_car),
                  ),
                  items: vehicles.map((v) {
                    return DropdownMenuItem(
                      value: v,
                      child: Text('${v.brand} ${v.model} - ${v.plate}', overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: onVehicleChanged,
                ),
          const SizedBox(height: 20),

          // Location
          const Text('Ubicación', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: locationController,
            decoration: const InputDecoration(
              hintText: 'Ej: Av. Principal km 15',
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onGetLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Usar ubicación GPS'),
          ),
          if (locationSelected && latitude != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'GPS: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: const Icon(Icons.emergency),
            label: const Text('Solicitar Ayuda', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared wizard progress indicator
// ─────────────────────────────────────────────────────────────────────────────
class _WizardProgress extends StatelessWidget {
  final int step;
  final int total;
  const _WizardProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i < step;
        return Expanded(
          child: Container(
            height: 4,
            margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
            decoration: BoxDecoration(
              color: active ? Colors.red : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}


