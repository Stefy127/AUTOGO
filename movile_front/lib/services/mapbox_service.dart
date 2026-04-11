import 'package:http/http.dart' as http;
import 'dart:convert';

class MapboxService {
  static const String _accessToken = 'sk.eyJ1IjoiYW5nZWxtb3JhMzciLCJhIjoiY21uczhzdWM3MDl5MzJzb244c3Fwd2d2biJ9.Ebk-DWFCC0TI1WxEnbPzzw';
  static const String _baseUrl = 'https://api.mapbox.com';

  /// Geocodificar una dirección a coordenadas
  Future<Map<String, double>?> geocodeAddress(String address) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocoding/v5/mapbox.places/${Uri.encodeComponent(address)}.json?access_token=$_accessToken&limit=1'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          final coordinates = data['features'][0]['geometry']['coordinates'];
          return {
            'latitude': coordinates[1],
            'longitude': coordinates[0],
          };
        }
      }
      return null;
    } catch (e) {
      print('Error en geocoding: $e');
      return null;
    }
  }

  /// Reverse geocoding: coordenadas a dirección
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/geocoding/v5/mapbox.places/$longitude,$latitude.json?access_token=$_accessToken'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['features'] != null && (data['features'] as List).isNotEmpty) {
          return data['features'][0]['place_name'];
        }
      }
      return null;
    } catch (e) {
      print('Error en reverse geocoding: $e');
      return null;
    }
  }

  /// Obtener distancia y duración entre dos puntos
  Future<Map<String, dynamic>?> getDistanceAndDuration({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    try {
      final coordinates = '$originLng,$originLat;$destLng,$destLat';
      final url = Uri.parse(
        '$_baseUrl/directions/v5/mapbox/driving/$coordinates?access_token=$_accessToken&geometries=geojson&overview=full'
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          return {
            'distance': route['distance'], // metros
            'duration': route['duration'], // segundos
            'durationMinutes': (route['duration'] / 60).round(),
            'geometry': route['geometry'],
          };
        }
      }
      return null;
    } catch (e) {
      print('Error calculando distancia: $e');
      return null;
    }
  }

  /// Obtener URL para imagen estática del mapa
  String getStaticMapUrl({
    required double latitude,
    required double longitude,
    int width = 600,
    int height = 400,
    int zoom = 14,
  }) {
    return '$_baseUrl/styles/v1/mapbox/streets-v12/static/pin-l-car+ff0000($longitude,$latitude)/$longitude,$latitude,$zoom/${width}x$height?access_token=$_accessToken';
  }

  /// Obtener URL para miniatura del mapa
  String getMapThumbnail({
    required double latitude,
    required double longitude,
  }) {
    return getStaticMapUrl(
      latitude: latitude,
      longitude: longitude,
      width: 300,
      height: 200,
      zoom: 13,
    );
  }
}
