// ============================================================================
// FLEET_PROVIDER.DART - CÓDIGO ACTUALIZADO CON TIEMPO REAL
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../database/vehicle_dao.dart';
import '../database/driver_dao.dart';
import '../services/realtime_service.dart';

class FleetProvider with ChangeNotifier {
  final VehicleDao _vehicleDao = VehicleDao();
  final DriverDao _driverDao = DriverDao();
  final RealtimeService _realtimeService = RealtimeService.instance;
  
  // Estado de los vehículos y conductores (usando Map desde DB)
  List<Vehicle> _vehicles = [];
  List<Map<String, dynamic>> _drivers = [];
  Map<String, dynamic> _driverLocations = {}; // Por código de conductor
  Map<String, String> _driverStatus = {}; // Por código de conductor
  
  // Estado de carga
  bool _isLoading = false;
  String? _error;
  
  // Timer para actualizaciones en tiempo real
  Timer? _locationUpdateTimer;
  
  // Suscripciones a streams de tiempo real
  StreamSubscription? _locationSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _geofenceSubscription;
  StreamSubscription? _allDriversSubscription;
  
  // Getters básicos
  List<Vehicle> get vehicles => _vehicles;
  List<Map<String, dynamic>> get drivers => _drivers;
  Map<String, dynamic> get driverLocations => _driverLocations;
  Map<String, String> get driverStatus => _driverStatus;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isRealtimeConnected => _realtimeService.isConnected;
  
  // Getters calculados para el dashboard
  int get totalVehicles => _vehicles.length;
  int get totalDrivers => _drivers.length;
  
  int get activeDrivers {
    return _driverStatus.values
        .where((status) => status == 'active')
        .length;
  }
  
  int get driversOnRoute {
    return _driverStatus.values
        .where((status) => status == 'on_route')
        .length;
  }
  
  int get connectedDrivers {
    return _drivers.where((driver) => 
        _isDriverConnected(driver['driver_code'] as String? ?? '')).length;
  }
  
  /// Cargar todos los datos de la flota
  Future<void> loadFleet() async {
    _setLoading(true);
    _error = null;
    
    try {
      // Cargar vehículos y conductores
      _vehicles = await _vehicleDao.getAllVehicles();
      _drivers = await _driverDao.getAllDrivers();
      
      // Inicializar estados de conductores
      for (var driver in _drivers) {
        String driverCode = driver['driver_code'] as String? ?? driver['id'].toString();
        _driverStatus[driverCode] = 'inactive'; // Estado inicial
      }
      
      // Conectar servicio de tiempo real
      await _connectRealtimeService();
      
      // Iniciar actualizaciones automáticas
      startRealTimeUpdates();
      
    } catch (e) {
      _error = 'Error cargando flota: $e';
      print(_error);
    } finally {
      _setLoading(false);
    }
  }
  
  /// Conectar al servicio de tiempo real
  Future<void> _connectRealtimeService() async {
    try {
      // Configurar servidor (ajustar según tu configuración)
      _realtimeService.configureServer('ws://localhost:3000');
      
      // Conectar
      await _realtimeService.connect();
      
      // Suscribirse a eventos
      _subscribeToRealtimeEvents();
      
      print('✅ Servicio de tiempo real conectado');
    } catch (e) {
      print('❌ Error conectando servicio de tiempo real: $e');
    }
  }
  
  /// Suscribirse a eventos de tiempo real
  void _subscribeToRealtimeEvents() {
    // Actualizaciones de ubicación
    _locationSubscription = _realtimeService.locationUpdates.listen((data) {
      _handleLocationUpdate(data);
    });
    
    // Cambios de estado de conductores
    _statusSubscription = _realtimeService.driverStatusUpdates.listen((data) {
      _handleDriverStatusUpdate(data);
    });
    
    // Alertas de geocerca
    _geofenceSubscription = _realtimeService.geofenceAlerts.listen((data) {
      _handleGeofenceAlert(data);
    });
    
    // Actualizaciones de todos los conductores
    _allDriversSubscription = _realtimeService.allDriversUpdates.listen((data) {
      _handleAllDriversUpdate(data);
    });
  }
  
  /// Manejar actualización de ubicación desde tiempo real
  void _handleLocationUpdate(Map<String, dynamic> data) {
    String driverCode = data['driverCode'] ?? '';
    double? lat = data['latitude']?.toDouble();
    double? lng = data['longitude']?.toDouble();
    double? speed = data['speed']?.toDouble();
    
    if (driverCode.isNotEmpty && lat != null && lng != null && speed != null) {
      updateDriverLocation(driverCode, lat, lng, speed);
    }
  }
  
  /// Manejar actualización de estado de conductor
  void _handleDriverStatusUpdate(Map<String, dynamic> data) {
    String driverCode = data['driverCode'] ?? '';
    String status = data['status'] ?? 'inactive';
    
    if (driverCode.isNotEmpty) {
      _driverStatus[driverCode] = status;
      notifyListeners();
    }
  }
  
  /// Manejar alerta de geocerca
  void _handleGeofenceAlert(Map<String, dynamic> data) {
    String type = data['type'] ?? '';
    String driverCode = data['driverCode'] ?? '';
    String driverName = data['driverName'] ?? '';
    
    print('🚨 Alerta de geocerca: $type - $driverName ($driverCode)');
    
    // Actualizar estado del conductor
    if (type == 'outside_geofence') {
      _driverStatus[driverCode] = 'alert';
      notifyListeners();
    }
  }
  
  /// Manejar actualización de todos los conductores
  void _handleAllDriversUpdate(List<Map<String, dynamic>> driversData) {
    for (var driverData in driversData) {
      String driverCode = driverData['driverCode'] ?? '';
      String status = driverData['status'] ?? 'inactive';
      
      if (driverCode.isNotEmpty) {
        _driverStatus[driverCode] = status;
        
        // Actualizar ubicación si está disponible
        if (driverData['location'] != null) {
          var location = driverData['location'];
          double? lat = location['latitude']?.toDouble();
          double? lng = location['longitude']?.toDouble();
          double? speed = location['speed']?.toDouble();
          
          if (lat != null && lng != null && speed != null) {
            _driverLocations[driverCode] = {
              'latitude': lat,
              'longitude': lng,
              'speed': speed,
              'timestamp': DateTime.now().toIso8601String(),
            };
          }
        }
      }
    }
    notifyListeners();
  }

  /// Refrescar datos de conductores
  Future<void> refreshDrivers() async {
    try {
      _setLoading(true);
      _error = null;
      
      // Recargar conductores desde la base de datos
      _drivers = await _driverDao.getAllDrivers();
      
      // Actualizar estados de conductores
      for (var driver in _drivers) {
        String driverCode = driver['driver_code'] as String? ?? driver['id'].toString();
        if (!_driverStatus.containsKey(driverCode)) {
          _driverStatus[driverCode] = 'inactive';
        }
      }
      
      // Solicitar datos actualizados del servidor
      if (_realtimeService.isConnected) {
        _realtimeService.requestAllDrivers();
      }
      
      // Verificar conexiones locales
      await _checkDriverConnections();
      
    } catch (e) {
      _error = 'Error refrescando conductores: $e';
      print(_error);
    } finally {
      _setLoading(false);
    }
  }
  
  /// Agregar nuevo conductor
  Future<bool> addDriver(Map<String, dynamic> driverData) async {
    try {
      _setLoading(true);
      
      // Generar código único si no existe
      if (driverData['driver_code'] == null) {
        driverData['driver_code'] = 'DRV_${DateTime.now().millisecondsSinceEpoch}';
      }
      
      final id = await _driverDao.insertDriver(driverData);
      driverData['id'] = id;
      
      _drivers.add(driverData);
      _driverStatus[driverData['driver_code']] = 'inactive';
      
      // Notificar al servidor de tiempo real
      if (_realtimeService.isConnected) {
        _realtimeService.sendDriverStatusUpdate(
          driverData['driver_code'], 
          'inactive'
        );
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error agregando conductor: $e';
      print(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Agregar nuevo vehículo
  Future<bool> addVehicle(Vehicle vehicle) async {
    try {
      _setLoading(true);
      
      final id = await _vehicleDao.insertVehicle(vehicle);
      vehicle.id = id;
      _vehicles.add(vehicle);
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error agregando vehículo: $e';
      print(_error);
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Obtener conductor por código
  Map<String, dynamic>? getDriverByCode(String code) {
    try {
      return _drivers.firstWhere((d) => 
          (d['driver_code'] as String? ?? d['id'].toString()) == code);
    } catch (e) {
      return null;
    }
  }
  
  /// Obtener vehículo por código de conductor
  Vehicle? getVehicleByDriverCode(String driverCode) {
    try {
      return _vehicles.firstWhere((v) => v.driver_code == driverCode);
    } catch (e) {
      return null;
    }
  }
  
  /// Actualizar ubicación de conductor (local y tiempo real)
  void updateDriverLocation(String driverCode, double lat, double lng, double speed) {
    _driverLocations[driverCode] = {
      'latitude': lat,
      'longitude': lng,
      'speed': speed,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    // Actualizar estado basado en velocidad
    String newStatus;
    if (speed > 5) {
      newStatus = 'active';
    } else if (speed > 0) {
      newStatus = 'on_route';
    } else {
      newStatus = 'inactive';
    }
    
    // Solo actualizar si cambió el estado
    if (_driverStatus[driverCode] != newStatus) {
      _driverStatus[driverCode] = newStatus;
      
      // Enviar actualización de estado al servidor
      if (_realtimeService.isConnected) {
        _realtimeService.sendDriverStatusUpdate(driverCode, newStatus);
      }
    }
    
    notifyListeners();
  }
  
  /// Actualizar estado de conductor
  void updateDriverStatus(String driverCode, String status) {
    _driverStatus[driverCode] = status;
    
    // Actualizar en la base de datos si es necesario
    _updateDriverInDatabase(driverCode, {
      'last_connection': DateTime.now().toIso8601String()
    });
    
    // Enviar al servidor de tiempo real
    if (_realtimeService.isConnected) {
      _realtimeService.sendDriverStatusUpdate(driverCode, status);
    }
    
    notifyListeners();
  }
  
  /// Actualizar conductor en base de datos
  Future<void> _updateDriverInDatabase(String driverCode, Map<String, dynamic> updates) async {
    try {
      final driver = getDriverByCode(driverCode);
      if (driver != null) {
        final updatedDriver = Map<String, dynamic>.from(driver);
        updatedDriver.addAll(updates);
        await _driverDao.updateDriver(updatedDriver);
      }
    } catch (e) {
      print('Error actualizando conductor en BD: $e');
    }
  }
  
  /// Iniciar actualizaciones en tiempo real
  void startRealTimeUpdates({int intervalSeconds = 30}) {
    stopRealTimeUpdates(); // Detener timer existente
    
    _locationUpdateTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (timer) async {
        await _checkDriverConnections();
        
        // Solicitar actualización de conductores del servidor
        if (_realtimeService.isConnected) {
          _realtimeService.requestAllDrivers();
        }
      },
    );
  }
  
  /// Verificar conexiones de conductores
  Future<void> _checkDriverConnections() async {
    final now = DateTime.now();
    for (var driver in _drivers) {
      String driverCode = driver['driver_code'] as String? ?? driver['id'].toString();
      String? lastConnectionStr = driver['updated_at'] as String?;
      
      if (lastConnectionStr != null) {
        try {
          final lastConnection = DateTime.parse(lastConnectionStr);
          final difference = now.difference(lastConnection);
          if (difference.inMinutes > 5) {
            _driverStatus[driverCode] = 'inactive';
          }
        } catch (e) {
          _driverStatus[driverCode] = 'inactive';
        }
      }
    }
    notifyListeners();
  }
  
  /// Verificar si un conductor está conectado
  bool _isDriverConnected(String driverCode) {
    final status = _driverStatus[driverCode];
    return status == 'active' || status == 'on_route';
  }
  
  /// Detener actualizaciones en tiempo real
  void stopRealTimeUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }
  
  /// Obtener conductores activos
  List<Map<String, dynamic>> get activeDriversList {
    return _drivers.where((d) {
      String driverCode = d['driver_code'] as String? ?? d['id'].toString();
      return _driverStatus[driverCode] == 'active';
    }).toList();
  }
  
  /// Obtener conductores conectados
  List<Map<String, dynamic>> get connectedDriversList {
    return _drivers.where((d) {
      String driverCode = d['driver_code'] as String? ?? d['id'].toString();
      return _isDriverConnected(driverCode);
    }).toList();
  }
  
  /// Obtener estado de un conductor específico
  String getDriverStatus(String driverCode) {
    return _driverStatus[driverCode] ?? 'inactive';
  }
  
  /// Obtener ubicación de un conductor específico
  dynamic getDriverLocation(String driverCode) {
    return _driverLocations[driverCode];
  }
  
  /// Obtener información completa de un conductor
  Map<String, dynamic>? getDriverInfo(String driverCode) {
    final driver = getDriverByCode(driverCode);
    if (driver == null) return null;
    
    return {
      ...driver,
      'status': getDriverStatus(driverCode),
      'location': getDriverLocation(driverCode),
      'vehicle': getVehicleByDriverCode(driverCode)?.toMap(),
    };
  }
  
  /// Eliminar conductor
  Future<bool> removeDriver(int driverId) async {
    try {
      _setLoading(true);
      
      await _driverDao.deleteDriver(driverId);
      _drivers.removeWhere((d) => d['id'] == driverId);
      
      // Limpiar estados relacionados
      String? driverCode;
      for (var entry in _driverStatus.entries) {
        final driver = getDriverByCode(entry.key);
        if (driver?['id'] == driverId) {
          driverCode = entry.key;
          break;
        }
      }
      
      if (driverCode != null) {
        _driverStatus.remove(driverCode);
        _driverLocations.remove(driverCode);
      }
      
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error eliminando conductor: $e';
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Reconectar servicio de tiempo real
  Future<void> reconnectRealtime() async {
    try {
      await _realtimeService.reconnect();
      if (_realtimeService.isConnected) {
        _subscribeToRealtimeEvents();
      }
    } catch (e) {
      print('Error reconectando tiempo real: $e');
    }
  }
  
  /// Limpiar errores
  void clearError() {
    _error = null;
    notifyListeners();
  }
  
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  @override
  void dispose() {
    stopRealTimeUpdates();
    
    // Cancelar suscripciones
    _locationSubscription?.cancel();
    _statusSubscription?.cancel();
    _geofenceSubscription?.cancel();
    _allDriversSubscription?.cancel();
    
    // Desconectar servicio de tiempo real
    _realtimeService.disconnect();
    
    super.dispose();
  }
}