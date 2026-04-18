import 'package:autogo_mobile/models/models.dart';
import 'api_service.dart';

class RentalVehiclesService {
  final ApiService _apiService = ApiService();

  Future<List<RentalVehicle>> getRentalVehicles({String? token}) async {
    try {
      final response = await _apiService.get('/rental-vehicles', token: token);
      if (response is List) {
        return response
            .map((json) => RentalVehicle.fromJson(json))
            .toList();
      }
      throw Exception('Invalid response format');
    } catch (e) {
      throw Exception('Error fetching rental vehicles: $e');
    }
  }

  Future<RentalVehicle> getRentalVehicleById(int id, {String? token}) async {
    try {
        final response = await _apiService.get('/rental-vehicles/$id', token: token);
        return RentalVehicle.fromJson(response as Map<String, dynamic>);
      } catch (e) {
        throw Exception('Error fetching rental vehicle: $e');
    }
  }

  Future<RentalVehicle> createRentalVehicle(
      Map<String, dynamic> data, String token) async {
    try {
        final response = await _apiService.post('/rental-vehicles', data, token: token);
        return RentalVehicle.fromJson(response as Map<String, dynamic>);
      } catch (e) {
        throw Exception('Error creating rental vehicle: $e');
    }
  }

  Future<RentalVehicle> updateRentalVehicle(
      int id, Map<String, dynamic> data, String token) async {
    try {
        final response = await _apiService.patch('/rental-vehicles/$id', data, token: token);
        return RentalVehicle.fromJson(response as Map<String, dynamic>);
      } catch (e) {
        throw Exception('Error updating rental vehicle: $e');
    }
  }

  Future<void> deleteRentalVehicle(int id, String token) async {
    try {
      await _apiService.delete('/rental-vehicles/$id', token: token);
    } catch (e) {
      throw Exception('Error deleting rental vehicle: $e');
    }
  }
}
