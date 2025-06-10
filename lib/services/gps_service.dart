// lib/services/gps_service.dart - CON SOCKET.IO
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:async';
import '../database/db_helper.dart';
import '../database/location_dao.dart';
import '../database/geofence_dao.dart';
import '../database/vehicle_dao.dart';
import '../models/location.dart';
import '../models/geofence.dart';
import 'geofence_service.dart';
import 'notification_service.dart';
import 'package:flutter/material.dart';

class GPSService {
  static final GPSService _instance = GPSService._internal();
  factory GPSService() => _instance;
  GPSService._internal();

  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeatTimer;
  IO.Socket? _socket;
  
  final LocationDao _locationDao = LocationDao();
  final GeofenceDao _geofenceDao = GeofenceDao();
  final VehicleDao _vehicleDao = VehicleDao();

  bool _isTracking = false;
  bool _isConnected = false;
  Position? _lastPosition;
  BuildContext? _context;
  int? _currentVehicleId;
  List<Geofence> _geofences = [];
  String? _currentDriverCode;

  // Configuración del servidor Socket.IO
  static const String _socketUrl = 'https://tu-servidor.com'; // Cambia por tu URL
  static const Duration _locationUpdateInterval = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 30);

  bool get isTracking => _isTracking;
  bool get isConnected => _isConnected;
  Position? get lastPosition => _lastPosition;

  void setContext(BuildContext context) {
    _context = context;
  }

  void setDriverCode(String? driverCode) {
    _currentDriverCode = driverCode;
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    if (_context != null && _context!.mounted) {
      ScaffoldMessenger.of(_context!).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor ?? Colors.red,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // NUEVA FUNCIÓN: Inicializar Socket.IO
  Future<void> initializeSocket() async {
    try {
      _socket = IO.io(_socketUrl, 
        IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setExtraHeaders({'Authorization': 'Bearer tu-token'}) // Si necesitas autenticación
          .build()
      );

      _socket!.onConnect((_) {
        print('Conectado al servidor Socket.IO');
        _isConnected = true;
        _showSnackBar('Conectado al servidor', backgroundColor: Colors.green);
        
        // Enviar información inicial del conductor/vehículo
        if (_currentVehicleId != null) {
          _socket!.emit('driver_connected', {
            'vehicle_id': _currentVehicleId,
            'driver_code': _currentDriverCode,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      });

      _socket!.onDisconnect((_) {
        print('Desconectado del servidor Socket.IO');
        _isConnected = false;
        _showSnackBar('Desconectado del servidor', backgroundColor: Colors.orange);
      });

      _socket!.onConnectError((error) {
        print('Error de conexión Socket.IO: $error');
        _isConnected = false;
        _showSnackBar('Error de conexión', backgroundColor: Colors.red);
      });

      // Escuchar comandos del servidor
      _socket!.on('command', (data) {
        _handleServerCommand(data);
      });

      // Escuchar actualizaciones de otros vehículos
      _socket!.on('vehicle_update', (data) {
        _handleVehicleUpdate(data);
      });

      _socket!.connect();
    } catch (e) {
      print('Error inicializando Socket.IO: $e');
    }
  }

  // NUEVA FUNCIÓN: Manejar comandos del servidor
  void _handleServerCommand(dynamic data) {
    try {
      final command = data['command'] as String?;
      switch (command) {
        case 'update_location':
          _requestLocationUpdate();
          break;
        case 'start_tracking':
          if (_currentVehicleId != null) {
            startTracking(_currentVehicleId!);
          }
          break;
        case 'stop_tracking':
          stopTracking();
          break;
        default:
          print('Comando desconocido: $command');
      }
    } catch (e) {
      print('Error procesando comando del servidor: $e');
    }
  }

  // NUEVA FUNCIÓN: Manejar actualizaciones de otros vehículos
  void _handleVehicleUpdate(dynamic data) {
    // Aquí puedes notificar a tu mapa para actualizar la posición de otros vehículos
    // Emitir evento para que el mapa se actualice
    print('Actualización de vehículo recibida: $data');
  }

  // NUEVA FUNCIÓN: Enviar ubicación al servidor
  Future<void> _sendLocationToServer(Position position) async {
    if (_socket != null && _isConnected && _currentVehicleId != null) {
      try {
        final locationData = {
          'vehicle_id': _currentVehicleId,
          'driver_code': _currentDriverCode,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'speed': position.speed,
          'heading': position.heading,
          'accuracy': position.accuracy,
          'timestamp': DateTime.now().toIso8601String(),
        };

        _socket!.emit('location_update', locationData);
        print('Ubicación enviada al servidor: ${position.latitude}, ${position.longitude}');
      } catch (e) {
        print('Error enviando ubicación al servidor: $e');
      }
    }
  }

  // NUEVA FUNCIÓN: Solicitar actualización de ubicación
  Future<void> _requestLocationUpdate() async {
    final position = await getCurrentPosition();
    if (position != null) {
      await _sendLocationToServer(position);
    }
  }

  // NUEVA FUNCIÓN: Heartbeat para mantener conexión
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_socket != null && _isConnected) {
        _socket!.emit('heartbeat', {
          'vehicle_id': _currentVehicleId,
          'driver_code': _currentDriverCode,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<bool> checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<Position?> getCurrentPosition() async {
    if (!await checkPermissions()) return null;
    if (!await isLocationServiceEnabled()) return null;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      _lastPosition = position;
      return position;
    } catch (e) {
      print('Error getting current position: $e');
      return null;
    }
  }

  // MODIFICADO: Iniciar tracking con Socket.IO
  Future<void> startTracking(int vehicleId, {String? driverCode}) async {
    if (_isTracking) return;

    if (!await checkPermissions() || !await isLocationServiceEnabled()) {
      throw Exception('Permisos de ubicación no concedidos o GPS desactivado');
    }

    _isTracking = true;
    _currentVehicleId = vehicleId;
    _currentDriverCode = driverCode;

    await _loadGeofences();
    
    // Inicializar Socket.IO si no está inicializado
    if (_socket == null) {
      await initializeSocket();
    }

    // Iniciar heartbeat
    _startHeartbeat();

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Reducido para más precisión
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) async {
      _lastPosition = position;
      
      // Guardar en base de datos local
      await _saveLocation(vehicleId, position);
      
      // Enviar al servidor Socket.IO
      await _sendLocationToServer(position);
      
      // Verificar geocercas y velocidad
      await _checkGeofences(vehicleId, position);
      await _checkSpeedLimit(vehicleId, position);
    });

    // Enviar ubicación inicial
    final currentPosition = await getCurrentPosition();
    if (currentPosition != null) {
      await _sendLocationToServer(currentPosition);
    }
  }

  // MODIFICADO: Detener tracking
  Future<void> stopTracking() async {
    if (_positionSubscription != null) {
      await _positionSubscription!.cancel();
      _positionSubscription = null;
    }

    // Notificar al servidor que se detuvo el tracking
    if (_socket != null && _isConnected && _currentVehicleId != null) {
      _socket!.emit('driver_disconnected', {
        'vehicle_id': _currentVehicleId,
        'driver_code': _currentDriverCode,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }

    _stopHeartbeat();
    _isTracking = false;
    _currentVehicleId = null;
    _currentDriverCode = null;
  }

  Future<void> _saveLocation(int vehicleId, Position position) async {
    final location = Location(
      latitude: position.latitude,
      longitude: position.longitude,
      timestamp: DateTime.now(),
      speed: position.speed,
      driverCode: _currentDriverCode,
    );

    await _locationDao.insertLocation(location);
  }

  Future<void> _loadGeofences() async {
    try {
      _geofences = await _geofenceDao.getAllGeofences();
    } catch (e) {
      print('Error cargando geocercas: $e');
      _geofences = [];
    }
  }

  Future<void> _checkGeofences(int vehicleId, Position position) async {
    for (final geofence in _geofences) {
      final isInside = GeofenceService.isInsideGeofence(
        position.latitude,
        position.longitude,
        geofence,
      );

      if (!isInside) {
        // Enviar alerta al servidor
        if (_socket != null && _isConnected) {
          _socket!.emit('geofence_alert', {
            'vehicle_id': vehicleId,
            'geofence_id': geofence.id,
            'geofence_name': geofence.name,
            'latitude': position.latitude,
            'longitude': position.longitude,
            'driver_code': _currentDriverCode,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }

        await NotificationService.showNotification(
          title: 'Alerta de Geocerca',
          body: 'El vehículo ha salido de la zona permitida: ${geofence.name}',
        );

        _showSnackBar(
          'Fuera de zona: ${geofence.name}',
          backgroundColor: Colors.red,
        );

        await _saveGeofenceAlert(vehicleId, geofence, position, false);
      }
    }
  }

  Future<void> _checkSpeedLimit(int vehicleId, Position position) async {
    try {
      final vehicle = await _vehicleDao.getVehicleById(vehicleId);
      if (vehicle?.maxSpeed != null) {
        final speedKmH = position.speed * 3.6;
        
        if (speedKmH > vehicle!.maxSpeed!) {
          // Enviar alerta de velocidad al servidor
          if (_socket != null && _isConnected) {
            _socket!.emit('speed_alert', {
              'vehicle_id': vehicleId,
              'current_speed': speedKmH,
              'speed_limit': vehicle.maxSpeed,
              'latitude': position.latitude,
              'longitude': position.longitude,
              'driver_code': _currentDriverCode,
              'timestamp': DateTime.now().toIso8601String(),
            });
          }

          await NotificationService.showNotification(
            title: 'Exceso de velocidad',
            body: 'Velocidad actual: ${speedKmH.toStringAsFixed(0)} km/h. Límite: ${vehicle.maxSpeed} km/h',
          );

          _showSnackBar(
            'Exceso de velocidad: ${speedKmH.toStringAsFixed(0)} km/h',
            backgroundColor: Colors.orange,
          );

          await _saveSpeedAlert(vehicleId, speedKmH, vehicle.maxSpeed!, position);
        }
      }
    } catch (e) {
      print('Error verificando límite de velocidad: $e');
    }
  }

  Future<void> _saveGeofenceAlert(int vehicleId, Geofence geofence, Position position, bool isInside) async {
    try {
      final db = await DBHelper.database;
      await db.insert('alerts', {
        'vehicle_id': vehicleId,
        'alert_type': 'GEOFENCE_VIOLATION',
        'message': isInside 
            ? 'Vehículo entró a geocerca: ${geofence.name}'
            : 'Vehículo salió de geocerca: ${geofence.name}',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
        'geofence_id': geofence.id,
        'driver_code': _currentDriverCode,
      });
    } catch (e) {
      print('Error guardando alerta de geocerca: $e');
    }
  }

  Future<void> _saveSpeedAlert(int vehicleId, double currentSpeed, double maxSpeed, Position position) async {
    try {
      final db = await DBHelper.database;
      await db.insert('alerts', {
        'vehicle_id': vehicleId,
        'alert_type': 'SPEED_LIMIT',
        'message': 'Exceso de velocidad: ${currentSpeed.toStringAsFixed(0)} km/h (límite: ${maxSpeed.toStringAsFixed(0)} km/h)',
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': 0,
        'current_speed': currentSpeed,
        'speed_limit': maxSpeed,
        'driver_code': _currentDriverCode,
      });
    } catch (e) {
      print('Error guardando alerta de velocidad: $e');
    }
  }

  // NUEVA FUNCIÓN: Actualización manual de ubicación
  Future<void> sendManualLocationUpdate() async {
    if (_currentVehicleId == null) return;
    
    final position = await getCurrentPosition();
    if (position != null) {
      await _sendLocationToServer(position);
      _showSnackBar('Ubicación actualizada', backgroundColor: Colors.green);
    }
  }

  Future<void> updateLocationInBackground() async {
    if (!await checkPermissions() || !await isLocationServiceEnabled()) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _lastPosition = position;
      
      if (_currentVehicleId != null) {
        await _saveLocation(_currentVehicleId!, position);
        await _sendLocationToServer(position);
      }
    } catch (e) {
      print('Error in background location update: $e');
    }
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  Future<void> dispose() async {
    await stopTracking();
    _stopHeartbeat();
    _socket?.disconnect();
    _socket?.dispose();
  }
}