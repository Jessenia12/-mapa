import '../database/db_helper.dart';
import '../models/vehicle.dart';
import '../models/driver.dart';
import '../models/location.dart';
import '../models/route.dart';
import 'api_service.dart';
import 'gps_service.dart';
import 'notification_service.dart';
import 'dart:async';
import 'dart:math';

class VehicleService {
  static final VehicleService _instance = VehicleService._internal();
  factory VehicleService() => _instance;
  VehicleService._internal();

  final GPSService _gpsService = GPSService();
  final NotificationService _notificationService = NotificationService();
  ApiService? _apiService;

  // Streams para tiempo real
  final StreamController<List<Vehicle>> _vehiclesController = StreamController<List<Vehicle>>.broadcast();
  final StreamController<Map<int, Location>> _locationsController = StreamController<Map<int, Location>>.broadcast();
  final StreamController<List<Driver>> _driversController = StreamController<List<Driver>>.broadcast();
  
  Stream<List<Vehicle>> get vehiclesStream => _vehiclesController.stream;
  Stream<Map<int, Location>> get locationsStream => _locationsController.stream;
  Stream<List<Driver>> get driversStream => _driversController.stream;

  Timer? _locationUpdateTimer;
  final Map<int, Location> _currentLocations = <int, Location>{};
  List<Vehicle> _vehicles = <Vehicle>[];
  List<Driver> _drivers = <Driver>[];

  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }

  // ============================================================================
  // GESTIÓN DE VEHÍCULOS
  // ============================================================================

  Future<List<Vehicle>> getAllVehicles() async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query('vehicles', orderBy: 'license_plate ASC');
      _vehicles = maps.map((map) => Vehicle.fromMap(map)).toList();
      _vehiclesController.add(_vehicles);
      return _vehicles;
    } catch (e) {
      print('Error obteniendo vehículos: $e');
      return <Vehicle>[];
    }
  }

  Future<Vehicle?> getVehicleById(int id) async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query('vehicles', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) {
        return Vehicle.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error obteniendo vehículo $id: $e');
      return null;
    }
  }

  Future<Vehicle?> createVehicle(Vehicle vehicle) async {
    try {
      final db = await DBHelper.database;
      final id = await db.insert('vehicles', vehicle.toMap());
      if (id > 0) {
        final newVehicle = vehicle.copyWith(id: id);
        await getAllVehicles(); // Actualiza la lista
        return newVehicle;
      }
      return null;
    } catch (e) {
      print('Error creando vehículo: $e');
      return null;
    }
  }

  Future<bool> updateVehicle(Vehicle vehicle) async {
    try {
      if (vehicle.id == null) return false;
      
      final db = await DBHelper.database;
      final result = await db.update(
        'vehicles',
        vehicle.toMap(),
        where: 'id = ?',
        whereArgs: [vehicle.id],
      );
      if (result > 0) {
        await getAllVehicles(); // Actualiza la lista
        return true;
      }
      return false;
    } catch (e) {
      print('Error actualizando vehículo: $e');
      return false;
    }
  }

  Future<bool> deleteVehicle(int id) async {
    try {
      final db = await DBHelper.database;
      final result = await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
      if (result > 0) {
        await getAllVehicles(); // Actualiza la lista
        return true;
      }
      return false;
    } catch (e) {
      print('Error eliminando vehículo: $e');
      return false;
    }
  }

  Future<Vehicle?> getVehicleByDriverCode(String driverCode) async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query('vehicles', where: 'driver_code = ?', whereArgs: [driverCode]);
      if (maps.isNotEmpty) {
        return Vehicle.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error obteniendo vehículo por código de conductor: $e');
      return null;
    }
  }

  // ============================================================================
  // GESTIÓN DE CONDUCTORES
  // ============================================================================

  Future<List<Driver>> getAllDrivers() async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query('drivers', orderBy: 'name ASC');
      _drivers = maps.map((map) => Driver.fromMap(map)).toList();
      _driversController.add(_drivers);
      return _drivers;
    } catch (e) {
      print('Error obteniendo conductores: $e');
      return <Driver>[];
    }
  }

  Future<Driver?> getDriverById(int id) async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query('drivers', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) {
        return Driver.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error obteniendo conductor $id: $e');
      return null;
    }
  }

  Future<Driver?> getDriverByCode(String code) async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query('drivers', where: 'code = ?', whereArgs: [code]);
      if (maps.isNotEmpty) {
        return Driver.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error obteniendo conductor por código: $e');
      return null;
    }
  }

  Future<Driver?> createDriver(Driver driver) async {
    try {
      final db = await DBHelper.database;
      final id = await db.insert('drivers', driver.toMap());
      if (id > 0) {
        final newDriver = driver.copyWith(id: id);
        await getAllDrivers(); // Actualiza la lista
        return newDriver;
      }
      return null;
    } catch (e) {
      print('Error creando conductor: $e');
      return null;
    }
  }

  Future<bool> updateDriver(Driver driver) async {
    try {
      if (driver.id == null) return false;
      
      final db = await DBHelper.database;
      final result = await db.update(
        'drivers',
        driver.toMap(),
        where: 'id = ?',
        whereArgs: [driver.id],
      );
      if (result > 0) {
        await getAllDrivers(); // Actualiza la lista
        return true;
      }
      return false;
    } catch (e) {
      print('Error actualizando conductor: $e');
      return false;
    }
  }

  Future<bool> deleteDriver(int id) async {
    try {
      final db = await DBHelper.database;
      final result = await db.delete('drivers', where: 'id = ?', whereArgs: [id]);
      if (result > 0) {
        await getAllDrivers(); // Actualiza la lista
        return true;
      }
      return false;
    } catch (e) {
      print('Error eliminando conductor: $e');
      return false;
    }
  }

  // ============================================================================
  // GESTIÓN DE UBICACIONES
  // ============================================================================

  Future<int> insertLocation(Location location) async {
    try {
      final db = await DBHelper.database;
      return await db.insert('locations', location.toMap());
    } catch (e) {
      print('Error insertando ubicación: $e');
      return 0;
    }
  }

  Future<List<Location>> getAllLocations() async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query('locations', orderBy: 'timestamp DESC');
      return maps.map((map) => Location.fromMap(map)).toList();
    } catch (e) {
      print('Error obteniendo ubicaciones: $e');
      return <Location>[];
    }
  }

  Future<List<Location>> getLocationsByDriver(String driverCode) async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query(
        'locations',
        where: 'driverCode = ?',
        whereArgs: [driverCode],
        orderBy: 'timestamp DESC',
      );
      return maps.map((map) => Location.fromMap(map)).toList();
    } catch (e) {
      print('Error obteniendo ubicaciones del conductor: $e');
      return <Location>[];
    }
  }

  Future<Location?> getLastLocation(String driverCode) async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query(
        'locations',
        where: 'driverCode = ?',
        whereArgs: [driverCode],
        orderBy: 'timestamp DESC',
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return Location.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error obteniendo última ubicación: $e');
      return null;
    }
  }

  Future<List<Location>> getVehicleLocations(int vehicleId, {DateTime? from, DateTime? to, int? limit}) async {
    try {
      final db = await DBHelper.database;
      
      // Primero obtenemos el vehículo para saber su driver_code
      final vehicle = await getVehicleById(vehicleId);
      if (vehicle?.driver_code == null || vehicle!.driver_code!.isEmpty) {
        return <Location>[];
      }

      String whereClause = 'driverCode = ?';
      List<dynamic> whereArgs = <dynamic>[vehicle.driver_code!];

      if (from != null) {
        whereClause += ' AND timestamp >= ?';
        whereArgs.add(from.toIso8601String());
      }

      if (to != null) {
        whereClause += ' AND timestamp <= ?';
        whereArgs.add(to.toIso8601String());
      }

      final maps = await db.query(
        'locations',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return maps.map((map) => Location.fromMap(map)).toList();
    } catch (e) {
      print('Error obteniendo historial de ubicaciones: $e');
      return <Location>[];
    }
  }

  // ============================================================================
  // VINCULACIÓN DE CONDUCTORES
  // ============================================================================

  Future<bool> linkDriverToVehicle(int driverId, int vehicleId, String linkCode) async {
    try {
      // Verificar que el código de vinculación sea válido
      final vehicle = await getVehicleById(vehicleId);
      if (vehicle == null) {
        print('Vehículo no encontrado');
        return false;
      }

      // Obtener el conductor
      final driver = await getDriverById(driverId);
      if (driver == null) {
        print('Conductor no encontrado'); 
        return false;
      }

      // Verificar que el conductor tenga un código válido
      if (driver.code.isEmpty) {
        print('El conductor no tiene un código válido');
        return false;
      }

      // Actualizar el vehículo con el código del conductor
      final db = await DBHelper.database;
      final result = await db.update(
        'vehicles',
        {'driver_code': driver.code},
        where: 'id = ?',
        whereArgs: [vehicleId],
      );

      if (result > 0) {
        await getAllVehicles(); // Refrescar la lista
        return true;
      }
      return false;
    } catch (e) {
      print('Error vinculando conductor: $e');
      return false;
    }
  }

  Future<String> generateLinkCode(int vehicleId) async {
    try {
      // Generar código único de 6 dígitos
      final random = Random();
      final code = (100000 + random.nextInt(900000)).toString();
      
      // Aquí podrías almacenar el código temporalmente en la base de datos
      // con una timestamp de expiración
      return code;
    } catch (e) {
      print('Error generando código: $e');
      return '';
    }
  }

  Future<Vehicle?> findVehicleByLinkCode(String linkCode) async {
    try {
      // Esta funcionalidad necesita una tabla adicional para códigos temporales
      // Por ahora retornamos null - implementar según tus necesidades
      return null;
    } catch (e) {
      print('Vehículo no encontrado con código: $linkCode');
      return null;
    }
  }

  // ============================================================================
  // RASTREO GPS EN TIEMPO REAL
  // ============================================================================

  Future<void> startFleetTracking() async {
    if (_locationUpdateTimer != null) return;

    print('Iniciando rastreo de flota...');
    
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      await _updateAllVehicleLocations();
    });

    // Actualización inicial
    await _updateAllVehicleLocations();
  }

  Future<void> stopFleetTracking() async {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
    print('Rastreo de flota detenido');
  }

  Future<void> _updateAllVehicleLocations() async {
    try {
      final vehicles = await getAllVehicles();
      final activeVehicles = vehicles.where((v) => v.driver_code != null && v.driver_code!.isNotEmpty).toList();
      
      for (final vehicle in activeVehicles) {
        if (vehicle.driver_code != null && vehicle.id != null) {
          final lastLocation = await getLastLocation(vehicle.driver_code!);
          if (lastLocation != null) {
            _currentLocations[vehicle.id!] = lastLocation;
          }
        }
      }
      
      _locationsController.add(Map<int, Location>.from(_currentLocations));
    } catch (e) {
      print('Error actualizando ubicaciones: $e');
    }
  }

  Future<List<Location>> getVehicleHistory(int vehicleId, {DateTime? from, DateTime? to, int? limit}) async {
    return await getVehicleLocations(vehicleId, from: from, to: to, limit: limit);
  }

  Location? getCurrentLocation(int vehicleId) {
    return _currentLocations[vehicleId];
  }

  // ============================================================================
  // GESTIÓN DE RUTAS
  // ============================================================================

  Future<List<Route>> getAllRoutes() async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query('routes', orderBy: 'assignedAt DESC');
      return maps.map((map) => Route.fromMap(map)).toList();
    } catch (e) {
      print('Error obteniendo rutas: $e');
      return <Route>[];
    }
  }

  Future<Route?> getRouteById(int id) async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query('routes', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) {
        return Route.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error obteniendo ruta $id: $e');
      return null;
    }
  }

  Future<Route?> createRoute(Route route) async {
    try {
      final db = await DBHelper.database;
      final id = await db.insert('routes', route.toMap());
      if (id > 0) {
        return route.copyWith(id: id);
      }
      return null;
    } catch (e) {
      print('Error creando ruta: $e');
      return null;
    }
  }

  Future<bool> updateRoute(Route route) async {
    try {
      if (route.id == null) return false;
      
      final db = await DBHelper.database;
      final result = await db.update(
        'routes',
        route.toMap(),
        where: 'id = ?',
        whereArgs: [route.id],
      );
      return result > 0;
    } catch (e) {
      print('Error actualizando ruta: $e');
      return false;
    }
  }

  Future<bool> assignRouteToVehicle(int routeId, int vehicleId, int driverId) async {
    try {
      final route = await getRouteById(routeId);
      final vehicle = await getVehicleById(vehicleId);
      final driver = await getDriverById(driverId);
      
      if (route == null || vehicle == null || driver == null) {
        return false;
      }

      // Actualizar la ruta con el código del conductor
      final updatedRoute = route.copyWith(
        driverCode: driver.code,
        status: 'assigned',
        assignedAt: DateTime.now(),
      );

      return await updateRoute(updatedRoute);
    } catch (e) {
      print('Error asignando ruta: $e');
      return false;
    }
  }

  Future<Route?> getActiveRouteForVehicle(int vehicleId) async {
    try {
      final vehicle = await getVehicleById(vehicleId);
      if (vehicle?.driver_code == null || vehicle!.driver_code!.isEmpty) return null;

      final db = await DBHelper.database;
      final maps = await db.query(
        'routes',
        where: 'driverCode = ? AND status IN (?, ?)',
        whereArgs: [vehicle.driver_code!, 'assigned', 'in_progress'],
        orderBy: 'assignedAt DESC',
        limit: 1,
      );

      if (maps.isNotEmpty) {
        return Route.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('Error obteniendo ruta activa: $e');
      return null;
    }
  }

  Future<List<Route>> getRoutesByDriver(String driverCode) async {
    try {
      final db = await DBHelper.database;
      final maps = await db.query(
        'routes',
        where: 'driverCode = ?',
        whereArgs: [driverCode],
        orderBy: 'assignedAt DESC',
      );
      return maps.map((map) => Route.fromMap(map)).toList();
    } catch (e) {
      print('Error obteniendo rutas del conductor: $e');
      return <Route>[];
    }
  }

  // ============================================================================
  // ALERTAS (placeholder - necesita implementación de tabla alerts)
  // ============================================================================

  Future<List<Map<String, dynamic>>> getVehicleAlerts(int vehicleId, {DateTime? from, DateTime? to}) async {
    try {
      // Implementar cuando tengas la tabla alerts
      // final db = await DBHelper.database;
      // final maps = await db.query('alerts', where: 'vehicleId = ?', whereArgs: [vehicleId]);
      return <Map<String, dynamic>>[];
    } catch (e) {
      print('Error obteniendo alertas: $e');
      return <Map<String, dynamic>>[];
    }
  }

  // ============================================================================
  // ESTADÍSTICAS Y REPORTES
  // ============================================================================

  Future<Map<String, dynamic>> getVehicleStats(int vehicleId, {DateTime? from, DateTime? to}) async {
    try {
      final locations = await getVehicleHistory(vehicleId, from: from, to: to);
      
      if (locations.isEmpty) {
        return {
          'totalDistance': 0.0,
          'averageSpeed': 0.0,
          'maxSpeed': 0.0,
          'totalTime': 0,
          'alerts': 0,
        };
      }

      double totalDistance = 0.0;
      double totalSpeed = 0.0;
      double maxSpeed = 0.0;
      int speedReadings = 0;

      for (int i = 1; i < locations.length; i++) {
        final prev = locations[i - 1];
        final curr = locations[i];
        
        final distance = _gpsService.calculateDistance(
          prev.latitude, prev.longitude,
          curr.latitude, curr.longitude,
        );
        totalDistance += distance;
        
        if (curr.speed > 0) {
          final speedKmh = curr.speed * 3.6; // Convert to km/h
          totalSpeed += speedKmh;
          speedReadings++;
          if (speedKmh > maxSpeed) {
            maxSpeed = speedKmh;
          }
        }
      }

      final totalTime = locations.last.timestamp.difference(locations.first.timestamp).inMinutes;
      final averageSpeed = speedReadings > 0 ? totalSpeed / speedReadings : 0.0;

      // Obtener alertas del período
      final alerts = await getVehicleAlerts(vehicleId, from: from, to: to);

      return {
        'totalDistance': totalDistance / 1000, // Convert to km
        'averageSpeed': averageSpeed,
        'maxSpeed': maxSpeed,
        'totalTime': totalTime,
        'alerts': alerts.length,
      };
    } catch (e) {
      print('Error calculando estadísticas: $e');
      return {
        'totalDistance': 0.0,
        'averageSpeed': 0.0,
        'maxSpeed': 0.0,
        'totalTime': 0,
        'alerts': 0,
      };
    }
  }

  Future<Map<String, dynamic>> getFleetStats({DateTime? from, DateTime? to}) async {
    try {
      final vehicles = await getAllVehicles();
      final activeVehicles = vehicles.where((v) => v.driver_code != null && v.driver_code!.isNotEmpty).length;
      
      double totalDistance = 0.0;
      int totalAlerts = 0;
      
      for (final vehicle in vehicles) {
        if (vehicle.id != null) {
          final stats = await getVehicleStats(vehicle.id!, from: from, to: to);
          totalDistance += stats['totalDistance'] as double;
          totalAlerts += stats['alerts'] as int;
        }
      }

      return {
        'totalVehicles': vehicles.length,
        'activeVehicles': activeVehicles,
        'totalDistance': totalDistance,
        'totalAlerts': totalAlerts,
        'averageDistancePerVehicle': vehicles.isNotEmpty ? totalDistance / vehicles.length : 0.0,
      };
    } catch (e) {
      print('Error calculando estadísticas de flota: $e');
      return {
        'totalVehicles': 0,
        'activeVehicles': 0,
        'totalDistance': 0.0,
        'totalAlerts': 0,
        'averageDistancePerVehicle': 0.0,
      };
    }
  }

  // ============================================================================
  // CLEANUP Y DISPOSE
  // ============================================================================

  Future<void> dispose() async {
    await stopFleetTracking();
    await _vehiclesController.close();
    await _locationsController.close();
    await _driversController.close();
  }

  // ============================================================================
  // UTILIDADES
  // ============================================================================

  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  String formatSpeed(double speed) {
    return '${speed.toStringAsFixed(0)} km/h';
  }

  String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${mins}m';
    } else {
      return '${mins}m';
    }
  }
}