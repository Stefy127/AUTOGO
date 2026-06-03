import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/mapbox_service.dart';

class IncidentTrackingScreen extends StatefulWidget {
  final Incident incident;

  const IncidentTrackingScreen({super.key, required this.incident});

  @override
  State<IncidentTrackingScreen> createState() => _IncidentTrackingScreenState();
}

class _IncidentTrackingScreenState extends State<IncidentTrackingScreen> {
  final MapboxService _mapboxService = MapboxService();
  String get _mapboxToken {
    const fromDefine = String.fromEnvironment('MAPBOX_ACCESS_TOKEN', defaultValue: '');
    if (fromDefine.isNotEmpty) return fromDefine;
    return dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    // Simple reconnect with 3s delay; avoid multiple concurrent attempts
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_socket == null || _socket?.closeCode != null) {
        _connectSocket();
      }
    });
  }

  WebSocket? _socket;
  bool _connecting = true;
  String? _error;
  String? _mapError;

  // Smooth marker animation
  Timer? _positionTimer;
  double? _animStartLat;
  double? _animStartLng;
  double? _animTargetLat;
  double? _animTargetLng;
  DateTime? _animStartTime;
  Duration _animDuration = const Duration(milliseconds: 800);

  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PointAnnotation? _clientMarker;
  PointAnnotation? _technicianMarker;
  PointAnnotation? _routeStartMarker;
  PointAnnotation? _routeEndMarker;
  PolylineAnnotation? _routePolylineAnnotation;
  Uint8List? _clientPinBytes;
  Uint8List? _technicianPinBytes;

  late String _status;
  int? _remainingDistanceMeters;
  DateTime? _estimatedArrivalTime;
  double? _technicianLatitude;
  double? _technicianLongitude;
  String? _routePolyline;
  DateTime? _lastUpdateAt;

  @override
  void initState() {
    super.initState();
    if (_mapboxToken.isNotEmpty) {
      MapboxOptions.setAccessToken(_mapboxToken);
    }
    _status = widget.incident.status;
    _remainingDistanceMeters = widget.incident.remainingDistanceMeters;
    _estimatedArrivalTime = widget.incident.estimatedArrivalTime;
    _routePolyline = widget.incident.routePolyline;
    _lastUpdateAt = widget.incident.lastEtaUpdateAt;
    _technicianLatitude = widget.incident.technician?.currentLatitude;
    _technicianLongitude = widget.incident.technician?.currentLongitude;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_socket == null) {
      _connectSocket();
    }
  }

  @override
  void dispose() {
    _socket?.close();
    super.dispose();
  }

  String? _buildStaticMapUrl() {
    final latitude = _technicianLatitude ?? widget.incident.latitude;
    final longitude = _technicianLongitude ?? widget.incident.longitude;
    if (latitude == null || longitude == null) {
      return null;
    }

    return _mapboxService.getStaticMapUrl(
      latitude: latitude,
      longitude: longitude,
      width: 1200,
      height: 700,
      zoom: 14,
    );
  }

  List<Position> _decodePolyline(String encoded) {
    final List<Position> coordinates = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);

      final int deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      shift = 0;
      result = 0;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);

      final int deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      coordinates.add(Position(lng / 1e5, lat / 1e5));
    }

    return coordinates;
  }

  Future<Uint8List> _buildPinBytes(Color color) async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2 - 8);

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 8);
    canvas.drawCircle(center.translate(0, 6), 24, shadowPaint);

    final tailPath = Path()
      ..moveTo(size / 2, size - 8)
      ..quadraticBezierTo(size / 2 - 16, size / 2 + 12, size / 2, size / 2 + 28)
      ..quadraticBezierTo(size / 2 + 16, size / 2 + 12, size / 2, size - 8)
      ..close();
    final tailPaint = Paint()..color = color;
    canvas.drawPath(tailPath, tailPaint);

    final bodyPaint = Paint()..color = color;
    canvas.drawCircle(center, 24, bodyPaint);

    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, 24, ringPaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, 8, dotPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  double _haversineDistanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const radius = 6371000.0;
    final phi1 = lat1 * (3.141592653589793 / 180.0);
    final phi2 = lat2 * (3.141592653589793 / 180.0);
    final dPhi = (lat2 - lat1) * (3.141592653589793 / 180.0);
    final dLambda = (lng2 - lng1) * (3.141592653589793 / 180.0);
    final a = (sin(dPhi / 2) * sin(dPhi / 2)) + (cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return radius * c;
  }

  CameraOptions _initialCameraOptions() {
    final lat = _technicianLatitude ?? widget.incident.latitude ?? -17.7833;
    final lng = _technicianLongitude ?? widget.incident.longitude ?? -63.1822;

    return CameraOptions(
      center: Point(coordinates: Position(lng, lat)),
      zoom: 13.5,
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    try {
      _pointAnnotationManager =
          await mapboxMap.annotations.createPointAnnotationManager();
      _polylineAnnotationManager =
          await mapboxMap.annotations.createPolylineAnnotationManager();
      await _refreshMapObjects();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mapError = 'No se pudo inicializar el mapa interactivo';
      });
    }
  }

  Future<void> _refreshMapObjects() async {
    final pointManager = _pointAnnotationManager;
    final lineManager = _polylineAnnotationManager;
    final map = _mapboxMap;
    if (pointManager == null || lineManager == null || map == null) return;

    try {
      if (_clientMarker != null) {
        await pointManager.delete(_clientMarker!);
        _clientMarker = null;
      }
      if (_technicianMarker != null) {
        await pointManager.delete(_technicianMarker!);
        _technicianMarker = null;
      }
      if (_routePolylineAnnotation != null) {
        await lineManager.delete(_routePolylineAnnotation!);
        _routePolylineAnnotation = null;
      }

      if (widget.incident.latitude != null &&
          widget.incident.longitude != null) {
        _clientPinBytes ??= await _buildPinBytes(Colors.red.shade600);
        _clientMarker = await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                  widget.incident.longitude!, widget.incident.latitude!),
            ),
            image: _clientPinBytes,
            iconAnchor: IconAnchor.BOTTOM,
          ),
        );
      }

      if (_technicianLatitude != null && _technicianLongitude != null) {
        _technicianPinBytes ??= await _buildPinBytes(Colors.blue.shade600);
        _technicianMarker = await pointManager.create(
          PointAnnotationOptions(
            geometry: Point(
              coordinates:
                  Position(_technicianLongitude!, _technicianLatitude!),
            ),
            image: _technicianPinBytes,
            iconAnchor: IconAnchor.BOTTOM,
          ),
        );
      }

      if (_routePolyline != null && _routePolyline!.isNotEmpty) {
        final coords = _decodePolyline(_routePolyline!);
        if (coords.length > 1) {
          // remove previous start/end markers
          if (_routeStartMarker != null) {
            await pointManager.delete(_routeStartMarker!);
            _routeStartMarker = null;
          }
          if (_routeEndMarker != null) {
            await pointManager.delete(_routeEndMarker!);
            _routeEndMarker = null;
          }

          _routePolylineAnnotation = await lineManager.create(
            PolylineAnnotationOptions(
              geometry: LineString(coordinates: coords),
              lineColor: 0xFF2563EB,
              lineWidth: 6,
            ),
          );

          // Create start and end markers for the route to improve visibility
          final start = coords.first;
          final end = coords.last;
          _routeStartMarker = await pointManager.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: start),
            ),
          );
          _routeEndMarker = await pointManager.create(
            PointAnnotationOptions(
              geometry: Point(coordinates: end),
            ),
          );
        }
      }

      // Center map: if both client and technician exist, center between them
      double? centerLat;
      double? centerLng;
      if (widget.incident.latitude != null && widget.incident.longitude != null && _technicianLatitude != null && _technicianLongitude != null) {
        centerLat = (widget.incident.latitude! + _technicianLatitude!) / 2.0;
        centerLng = (widget.incident.longitude! + _technicianLongitude!) / 2.0;
      } else if (_technicianLatitude != null && _technicianLongitude != null) {
        centerLat = _technicianLatitude;
        centerLng = _technicianLongitude;
      } else if (widget.incident.latitude != null && widget.incident.longitude != null) {
        centerLat = widget.incident.latitude;
        centerLng = widget.incident.longitude;
      }

      if (centerLat != null && centerLng != null) {
        double zoom = 14.0;
        if (widget.incident.latitude != null && widget.incident.longitude != null && _technicianLatitude != null && _technicianLongitude != null) {
          final dist = _haversineDistanceMeters(widget.incident.latitude!, widget.incident.longitude!, _technicianLatitude!, _technicianLongitude!);
          if (dist < 200) {
            zoom = 15.0;
          } else if (dist < 1000) {
            zoom = 14.0;
          } else if (dist < 5000) {
            zoom = 13.0;
          } else {
            zoom = 12.0;
          }
        }

        await map.flyTo(
          CameraOptions(
            center: Point(coordinates: Position(centerLng, centerLat)),
            zoom: zoom,
          ),
          MapAnimationOptions(duration: 1200),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mapError = 'No se pudo actualizar el mapa en tiempo real';
      });
    }
  }

  String _formatDistance(int meters) {
    if (meters >= 1000) {
      final km = (meters / 1000);
      return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
    }
    return '$meters m';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    return '${diff.inHours}h';
  }

  String _formatEta(DateTime eta) {
    final remaining = eta.difference(DateTime.now());
    if (remaining.inSeconds <= 0) return '0m';
    if (remaining.inSeconds < 60) return '${remaining.inSeconds}s';
    if (remaining.inMinutes < 60) return '${remaining.inMinutes}m';
    if (remaining.inHours < 24) return '${remaining.inHours}h';
    return '${remaining.inDays}d';
  }

  Future<void> _connectSocket() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final token = authService.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _connecting = false;
        _error = 'No se encontró sesión activa';
      });
      return;
    }

    try {
      final wsBaseUrl = ApiService.baseUrl
          .replaceFirst('https://', 'wss://')
          .replaceFirst('http://', 'ws://');
      final socketUrl =
          '$wsBaseUrl/incidents/ws/incidents/${widget.incident.id}?token=${Uri.encodeComponent(token)}';
      final socket = await WebSocket.connect(socketUrl);
      _socket = socket;

      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = null;
      });

      socket.listen(
        _handleSocketMessage,
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _error = 'Conexión en tiempo real no disponible';
          });
          _scheduleReconnect();
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            _error = _error ?? 'Conexión finalizada';
          });
          _scheduleReconnect();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = 'No se pudo conectar al seguimiento en tiempo real';
      });
    }
  }

  void _handleSocketMessage(dynamic message) {
    try {
      // Debug: log raw socket message
      // ignore: avoid_print
      print('WS message raw: $message');
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type']?.toString();

      if (!mounted) return;

      setState(() {
          if (type == 'status_update') {
          _status = data['status']?.toString() ?? _status;
        }

        if (type == 'tracking_update') {
          final newLat = (data['latitude'] as num?)?.toDouble();
          final newLng = (data['longitude'] as num?)?.toDouble();
          if (newLat != null && newLng != null) {
            _animateTo(newLat, newLng);
          }
          _remainingDistanceMeters =
              (data['remaining_distance_meters'] as num?)?.toInt() ??
                  _remainingDistanceMeters;
          final etaSeconds = (data['estimated_arrival_time'] as num?)?.toInt();
          if (etaSeconds != null) {
            _estimatedArrivalTime =
                DateTime.now().add(Duration(seconds: etaSeconds));
          }
          // Debug prints for distance and ETA
          // ignore: avoid_print
          print('tracking_update: remaining_distance_meters=$_remainingDistanceMeters, eta_seconds=$etaSeconds');
          _routePolyline = data['route_polyline']?.toString() ?? _routePolyline;
          _lastUpdateAt = DateTime.now();
        }
        if (type == 'notification') {
          final title = data['title']?.toString() ?? 'Notificación';
          final message = data['message']?.toString() ?? '';
          // Mostrar SnackBar breve para notificaciones en tiempo real
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title — $message'),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      });
      _refreshMapObjects();
    } catch (_) {
      // Se ignoran mensajes inválidos para no interrumpir la vista.
    }
  }

  void _animateTo(double lat, double lng) {
    // Cancel previous animation
    _positionTimer?.cancel();

    _animStartLat = _technicianLatitude ?? widget.incident.latitude ?? lat;
    _animStartLng = _technicianLongitude ?? widget.incident.longitude ?? lng;
    _animTargetLat = lat;
    _animTargetLng = lng;
    _animStartTime = DateTime.now();

    _positionTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      final now = DateTime.now();
      final elapsed = now.difference(_animStartTime!);
      final t = (elapsed.inMilliseconds / _animDuration.inMilliseconds).clamp(0, 1);

      final interpLat = _animStartLat! + (_animTargetLat! - _animStartLat!) * t;
      final interpLng = _animStartLng! + (_animTargetLng! - _animStartLng!) * t;

      _technicianLatitude = interpLat;
      _technicianLongitude = interpLng;

      // Update map objects frequently for smooth motion
      _refreshMapObjects();

      if (t >= 1.0) {
        timer.cancel();
        _positionTimer = null;
        _technicianLatitude = _animTargetLat;
        _technicianLongitude = _animTargetLng;
        _refreshMapObjects();
      }
    });
  }

  Widget _buildInteractiveMap() {
    if (_mapboxToken.isEmpty) {
      return _buildMapFallback(
        message: 'MAPBOX_ACCESS_TOKEN no está configurado en Flutter',
      );
    }

    if (_mapError != null) {
      return _buildMapFallback(message: _mapError!);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 320,
        child: Stack(
          children: [
            MapWidget(
              key: const ValueKey('incident-tracking-mapbox'),
              cameraOptions: _initialCameraOptions(),
              styleUri: MapboxStyles.MAPBOX_STREETS,
              onMapCreated: _onMapCreated,
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(text: _status),
                  if (_remainingDistanceMeters != null)
                    _InfoChip(text: _formatDistance(_remainingDistanceMeters!)),
                  if (_estimatedArrivalTime != null)
                    _InfoChip(
                      text: 'ETA ${_formatEta(_estimatedArrivalTime!)}',
                    ),
                  if (_lastUpdateAt != null)
                    _InfoChip(text: 'Actualizado ${_timeAgo(_lastUpdateAt!)}'),
                ],
              ),
            ),
            // Leyenda visual: Cliente vs Técnico
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cliente
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Cliente', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Técnico
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('Técnico', style: TextStyle(fontSize: 13)),
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

  Widget _buildMapFallback({String? message}) {
    final mapUrl = _buildStaticMapUrl();
    if (mapUrl != null && mapUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Image.network(
            mapUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: Text(message ?? 'No se pudo cargar el mapa'),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(message ?? 'Ubicación del técnico no disponible aún'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Seguimiento #${widget.incident.id}'),
      ),
      body: _connecting
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _socket?.close();
                _socket = null;
                await _connectSocket();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_error!),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.incident.description,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          if (widget.incident.workshop != null)
                            Text('Taller: ${widget.incident.workshop!.name}'),
                          if (widget.incident.technician != null)
                            Text(
                                'Técnico: ${widget.incident.technician!.name}'),
                          if (_lastUpdateAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Actualizado ${_lastUpdateAt!.toLocal()}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildInteractiveMap(),
                  const SizedBox(height: 16),
                  if (_routePolyline != null)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ruta estimada',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              _routePolyline!,
                              style: const TextStyle(fontSize: 12),
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

class _StatusChip extends StatelessWidget {
  final String text;

  const _StatusChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.blue.shade900,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;

  const _InfoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.green.shade900,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
