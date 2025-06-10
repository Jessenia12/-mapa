// services/api_service.dart - MODIFICADO
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/vehicle.dart';

class ApiService {
  final String baseUrl;
  
  ApiService({required this.baseUrl});

  // ============================================================================
  // MÉTODOS HTTP BÁSICOS
  // ============================================================================

  /// Método GET mejorado
  Future<dynamic> get(String endpoint) async {
    try {
      print('GET Request: $baseUrl$endpoint'); // Para debug
      
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 30));
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } catch (e) {
      print('Error en GET: $e');
      throw Exception('Error: $e');
    }
  }

  /// Método POST mejorado
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      print('POST Request: $baseUrl$endpoint');
      print('POST Data: ${jsonEncode(data)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 30));
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } catch (e) {
      print('Error en POST: $e');
      throw Exception('Error: $e');
    }
  }

  /// Método PUT
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      print('PUT Request: $baseUrl$endpoint');
      print('PUT Data: ${jsonEncode(data)}');
      
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 30));
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } catch (e) {
      print('Error en PUT: $e');
      throw Exception('Error: $e');
    }
  }

  /// Método DELETE
  Future<dynamic> delete(String endpoint) async {
    try {
      print('DELETE Request: $baseUrl$endpoint');
      
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(Duration(seconds: 30));
      
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.isNotEmpty) {
          return jsonDecode(response.body);
        }
        return {'success': true};
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } on SocketException {
      throw Exception('Sin conexión a internet');
    } catch (e) {
      print('Error en DELETE: $e');
      throw Exception('Error: $e');
    }
  }

  // ============================================================================
  // MÉTODOS PARA VEHÍCULOS
  // ============================================================================

  /// Obtener todos los vehículos
  Future<List<Vehicle>> getVehicles() async {
    try {
      final response = await get('/vehicles');
      
      if (response is Map && response['data'] != null) {
        return (response['data'] as List)
            .map((json) => Vehicle.fromMap(json))
            .toList();
      } else if (response is List) {
        return response.map((json) => Vehicle.fromMap(json)).toList();
      }
      
      return [];
    } catch (e) {
      print('Error obteniendo vehículos: $e');
      return [];
    }
  }

  /// Obtener un vehículo por ID
  Future<Vehicle?> getVehicle(int vehicleId) async {
    try {
      final response = await get('/vehicles/$vehicleId');
      
      if (response['data'] != null) {
        return Vehicle.fromMap(response['data']);
      }
      
      return null;
    } catch (e) {
      print('Error obteniendo vehículo $vehicleId: $e');
      return null;
    }
  }

  /// Crear nuevo vehículo
  Future<Vehicle?> createVehicle(Vehicle vehicle) async {
    try {
      final response = await post('/vehicles', vehicle.toMap());
      
      if (response['data'] != null) {
        return Vehicle.fromMap(response['data']);
      }
      
      return null;
    } catch (e) {
      print('Error creando vehículo: $e');
      return null;
    }
  }

  /// Actualizar vehículo existente
  Future<Vehicle?> updateVehicle(int vehicleId, Vehicle vehicle) async {
    try {
      final response = await put('/vehicles/$vehicleId', vehicle.toMap());
      
      if (response['data'] != null) {
        return Vehicle.fromMap(response['data']);
      }
      
      return null;
    } catch (e) {
      print('Error actualizando vehículo $vehicleId: $e');
      return null;
    }
  }

  /// Eliminar vehículo
  Future<bool> deleteVehicle(int vehicleId) async {
    try {
      await delete('/vehicles/$vehicleId');
      return true;
    } catch (e) {
      print('Error eliminando vehículo $vehicleId: $e');
      return false;
    }
  }

  // ============================================================================
  // MÉTODOS PARA UBICACIONES Y RASTREO GPS
  // ============================================================================

  /// Obtener ubicación actual de un vehículo específico
  Future<Map<String, dynamic>?> getVehicleLocation(int vehicleId) async {
    try {
      final response = await get('/vehicles/$vehicleId/location');
      
      if (response['data'] != null) {
        return {
          'latitude': response['data']['latitude']?.toDouble() ?? 0.0,
          'longitude': response['data']['longitude']?.toDouble() ?? 0.0,
          'timestamp': response['data']['timestamp'],
          'speed': response['data']['speed']?.toDouble() ?? 0.0,
          'direction': response['data']['direction']?.toDouble() ?? 0.0,
          'accuracy': response['data']['accuracy']?.toDouble() ?? 0.0,
        };
      }
      
      return null;
    } catch (e) {
      print('Error obteniendo ubicación del vehículo $vehicleId: $e');
      return null;
    }
  }

  /// Obtener ubicaciones de todos los vehículos activos
  Future<Map<int, dynamic>> getAllVehicleLocations() async {
    try {
      final response = await get('/vehicles/locations');
      
      Map<int, dynamic> locations = {};
      
      if (response['data'] != null && response['data'] is List) {
        for (var item in response['data']) {
          final vehicleId = item['vehicle_id'];
          if (vehicleId != null) {
            locations[vehicleId] = {
              'latitude': item['latitude']?.toDouble() ?? 0.0,
              'longitude': item['longitude']?.toDouble() ?? 0.0,
              'timestamp': item['timestamp'],
              'speed': item['speed']?.toDouble() ?? 0.0,
              'direction': item['direction']?.toDouble() ?? 0.0,
              'accuracy': item['accuracy']?.toDouble() ?? 0.0,
            };
          }
        }
      }
      
      return locations;
    } catch (e) {
      print('Error obteniendo ubicaciones: $e');
      return {};
    }
  }

  /// Actualizar ubicación de un vehículo (para dispositivos GPS)
  Future<bool> updateVehicleLocation(
    int vehicleId, 
    double lat, 
    double lng, {
    double? speed,
    double? direction,
    double? accuracy,
  }) async {
    try {
      final data = {
        'vehicle_id': vehicleId,
        'latitude': lat,
        'longitude': lng,
        'timestamp': DateTime.now().toIso8601String(),
        'speed': speed ?? 0.0,
        'direction': direction ?? 0.0,
        'accuracy': accuracy ?? 0.0,
      };
      
      final response = await post('/vehicles/$vehicleId/location', data);
      return response != null;
    } catch (e) {
      print('Error actualizando ubicación: $e');
      return false;
    }
  }

  /// Obtener historial de ubicaciones de un vehículo
  Future<List<Map<String, dynamic>>> getVehicleHistory(
    int vehicleId, 
    DateTime startDate, 
    DateTime endDate
  ) async {
    try {
      final response = await get(
        '/vehicles/$vehicleId/history?start=${startDate.toIso8601String()}&end=${endDate.toIso8601String()}'
      );
      
      if (response['data'] != null && response['data'] is List) {
        return List<Map<String, dynamic>>.from(response['data']);
      }
      return [];
    } catch (e) {
      print('Error obteniendo historial: $e');
      return [];
    }
  }

  // ============================================================================
  // MÉTODOS PARA ESTADOS DE VEHÍCULOS
  // ============================================================================

  /// Obtener estado actual de los vehículos (en movimiento, estacionado, etc.)
  Future<Map<int, String>> getVehicleStatuses() async {
    try {
      final response = await get('/vehicles/status');
      
      Map<int, String> statuses = {};
      
      if (response['data'] != null && response['data'] is List) {
        for (var item in response['data']) {
          final vehicleId = item['vehicle_id'];
          if (vehicleId != null) {
            statuses[vehicleId] = item['status'] ?? 'Sin datos';
          }
        }
      }
      
      return statuses;
    } catch (e) {
      print('Error obteniendo estados: $e');
      return {};
    }
  }

  /// Actualizar estado de un vehículo
  Future<bool> updateVehicleStatus(int vehicleId, String status) async {
    try {
      final data = {
        'vehicle_id': vehicleId,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final response = await post('/vehicles/$vehicleId/status', data);
      return response != null;
    } catch (e) {
      print('Error actualizando estado: $e');
      return false;
    }
  }

  // ============================================================================
  // MÉTODOS PARA GEOCERCAS
  // ============================================================================

  /// Obtener todas las geocercas
  Future<List<dynamic>> getGeofences() async {
    try {
      final response = await get('/geofences');
      
      if (response['data'] != null && response['data'] is List) {
        return response['data'];
      } else if (response is List) {
        return response;
      }
      
      return [];
    } catch (e) {
      print('Error obteniendo geocercas: $e');
      return [];
    }
  }

  /// Verificar si un vehículo está dentro de una geocerca
  Future<bool> checkGeofenceViolation(int vehicleId, double lat, double lng) async {
    try {
      final data = {
        'vehicle_id': vehicleId,
        'latitude': lat,
        'longitude': lng,
      };
      
      final response = await post('/geofences/check', data);
      return response['violation'] == true;
    } catch (e) {
      print('Error verificando geocerca: $e');
      return false;
    }
  }

  // ============================================================================
  // MÉTODOS PARA ALERTAS Y NOTIFICACIONES
  // ============================================================================

  /// Obtener alertas activas
  Future<List<dynamic>> getActiveAlerts() async {
    try {
      final response = await get('/alerts/active');
      
      if (response['data'] != null && response['data'] is List) {
        return response['data'];
      }
      
      return [];
    } catch (e) {
      print('Error obteniendo alertas: $e');
      return [];
    }
  }

  /// Crear nueva alerta
  Future<bool> createAlert(Map<String, dynamic> alertData) async {
    try {
      final response = await post('/alerts', alertData);
      return response != null;
    } catch (e) {
      print('Error creando alerta: $e');
      return false;
    }
  }

  // ============================================================================
  // MÉTODOS DE UTILIDAD
  // ============================================================================

  /// Verificar conectividad
  Future<bool> checkConnection() async {
    try {
      final response = await get('/health');
      return response != null;
    } catch (e) {
      print('Error verificando conexión: $e');
      return false;
    }
  }

  /// Obtener información del servidor
  Future<Map<String, dynamic>?> getServerInfo() async {
    try {
      final response = await get('/info');
      return response['data'];
    } catch (e) {
      print('Error obteniendo info del servidor: $e');
      return null;
    }
  }
}