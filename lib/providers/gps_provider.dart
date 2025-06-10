import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/driver.dart';
import '../database/driver_dao.dart';

class GPSProvider extends ChangeNotifier {
  static const String SERVER_URL = 'ws://tu-servidor.com:3000'; // Cambia por tu URL
  
  Driver? _currentDriver;
  Position? _currentPosition;
  bool _isTracking = false;
  bool _isConnected = false;
  IO.Socket? _socket;
  Stream<Position>? _positionStream;
  
  // Estado de ubicación
  String _locationStatus = 'Desconectado';
  double _currentSpeed = 0.0;
  double _accuracy = 0.0;
  
  // Getters
  Driver? get currentDriver => _currentDriver;
  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get isConnected => _isConnected;
  String get locationStatus => _locationStatus;
  double get currentSpeed => _currentSpeed;
  double get accuracy => _accuracy;

  // Configurar el conductor actual
  void setDriver(Driver driver) {
    _currentDriver = driver;
    _locationStatus = 'Conductor configurado';
    notifyListeners();
  }

  // Iniciar el tracking GPS y conexión socket
  Future<void> startTracking() async {
    if (_currentDriver == null) {
      throw Exception('No hay conductor configurado');
    }

    try {
      // Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permisos de ubicación denegados');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos de ubicación denegados permanentemente');
      }

      // Verificar si el GPS está habilitado
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Los servicios de ubicación están deshabilitados');
      }

      // Configurar y conectar socket
      await _initializeSocket();

      // Configurar el stream de ubicación
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Actualizar cada 5 metros
        timeLimit: Duration(seconds: 10),
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      );

      // Escuchar cambios de posición
      _positionStream!.listen(
        _onPositionUpdate,
        onError: _onLocationError,
        cancelOnError: false,
      );

      // Obtener posición inicial
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _isTracking = true;
      _locationStatus = 'Rastreando ubicación';
      
      // Enviar posición inicial
      await _sendLocationUpdate(_currentPosition!);
      
      // Actualizar estado del conductor en BD
      await _updateDriverStatusInDB('active');

      notifyListeners();
    } catch (e) {
      _locationStatus = 'Error: $e';
      notifyListeners();
      rethrow;
    }
  }

  // Detener el tracking
  Future<void> stopTracking() async {
    _isTracking = false;
    _locationStatus = 'Tracking detenido';
    
    // Cerrar socket
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;

    // Actualizar estado del conductor en BD
    if (_currentDriver != null) {
      await _updateDriverStatusInDB('inactive');
    }

    notifyListeners();
  }

  // Inicializar conexión socket
  Future<void> _initializeSocket() async {
    if (_currentDriver == null) return;

    try {
      _socket = IO.io(SERVER_URL, 
        IO.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .setExtraHeaders({
            'driver_id': _currentDriver!.id.toString(),
            'driver_code': _currentDriver!.code,
          })
          .build()
      );

      _socket!.onConnect((_) {
        print('Socket conectado para conductor: ${_currentDriver!.name}');
        _isConnected = true;
        _locationStatus = 'Conectado al servidor';
        
        // Registrar conductor en el servidor
        _socket!.emit('driver_connect', {
          'driver_id': _currentDriver!.id,
          'driver_code': _currentDriver!.code,
          'name': _currentDriver!.name,
          'plate_number': _currentDriver!.plateNumber,
        });
        
        notifyListeners();
      });

      _socket!.onDisconnect((_) {
        print('Socket desconectado');
        _isConnected = false;
        _locationStatus = 'Desconectado del servidor';
        notifyListeners();
      });

      _socket!.onConnectError((error) {
        print('Error de conexión socket: $error');
        _isConnected = false;
        _locationStatus = 'Error de conexión';
        notifyListeners();
      });

      // Escuchar mensajes del servidor
      _socket!.on('location_received', (data) {
        print('Ubicación recibida por el servidor: $data');
      });

      _socket!.on('driver_status_update', (data) {
        print('Estado del conductor actualizado: $data');
      });

      _socket!.connect();
    } catch (e) {
      print('Error inicializando socket: $e');
      _locationStatus = 'Error de conexión socket';
      notifyListeners();
    }
  }

  // Manejar actualizaciones de posición
  void _onPositionUpdate(Position position) async {
    _currentPosition = position;
    _currentSpeed = position.speed * 3.6; // Convertir m/s a km/h
    _accuracy = position.accuracy;
    
    if (_isTracking && _currentDriver != null) {
      // Enviar ubicación al servidor
      await _sendLocationUpdate(position);
      
      // Actualizar en base de datos local
      await _updateDriverLocationInDB(position);
      
      _locationStatus = 'Ubicación actualizada - ${_currentSpeed.toStringAsFixed(1)} km/h';
    }
    
    notifyListeners();
  }

  // Manejar errores de ubicación
  void _onLocationError(dynamic error) {
    print('Error de ubicación: $error');
    _locationStatus = 'Error obteniendo ubicación: $error';
    notifyListeners();
  }

  // Enviar ubicación al servidor via socket
  Future<void> _sendLocationUpdate(Position position) async {
    if (_socket != null && _isConnected && _currentDriver != null) {
      final locationData = {
        'driver_id': _currentDriver!.id,
        'driver_code': _currentDriver!.code,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed': position.speed * 3.6, // km/h
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'heading': position.heading,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'active',
      };

      _socket!.emit('location_update', locationData);
      print('Ubicación enviada: ${position.latitude}, ${position.longitude}');
    }
  }

  // Actualizar ubicación del conductor en base de datos
  Future<void> _updateDriverLocationInDB(Position position) async {
    if (_currentDriver != null) {
      try {
        await DriverDao().updateDriverLocation(
          _currentDriver!.id!,
          position.latitude,
          position.longitude,
          position.speed * 3.6, // Convertir a km/h
        );

        // Actualizar el objeto driver local
        _currentDriver = _currentDriver!.copyWith(
          lastLatitude: position.latitude,
          lastLongitude: position.longitude,
          lastSpeed: position.speed * 3.6,
          lastConnection: DateTime.now(),
          currentStatus: 'active',
        );
      } catch (e) {
        print('Error actualizando ubicación en BD: $e');
      }
    }
  }

  // Actualizar estado del conductor en BD
  Future<void> _updateDriverStatusInDB(String status) async {
    if (_currentDriver != null) {
      try {
        final updatedDriver = _currentDriver!.copyWith(
          currentStatus: status,
          lastConnection: DateTime.now(),
          isActive: status == 'active',
        );

        await DriverDao().updateDriver(updatedDriver.toMap());
        _currentDriver = updatedDriver;
      } catch (e) {
        print('Error actualizando estado en BD: $e');
      }
    }
  }

  // Obtener última ubicación conocida
  Future<Position?> getLastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      print('Error obteniendo última ubicación: $e');
      return null;
    }
  }

  // Limpiar recursos
  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }

  // Método para forzar actualización de ubicación
  Future<void> forceLocationUpdate() async {
    if (_isTracking) {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _onPositionUpdate(position);
      } catch (e) {
        print('Error forzando actualización de ubicación: $e');
      }
    }
  }

  // Verificar estado de permisos
  Future<LocationPermission> checkPermissionStatus() async {
    return await Geolocator.checkPermission();
  }

  // Verificar si los servicios de ubicación están habilitados
  Future<bool> checkLocationServiceStatus() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}