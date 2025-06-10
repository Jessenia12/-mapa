// lib/services/admin_tracking_service.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class AdminTrackingService {
  IO.Socket? _socket;
  final Map<String, LatLng> _driverPositions = {};
  final StreamController<Map<String, dynamic>> _locationController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final Completer<void> _connectionCompleter = Completer<void>();
  StreamSubscription? _networkSubscription;
  bool _shouldReconnect = true;
  String _serverUrl = 'http://192.168.100.141:3000';

  bool get isConnected => _socket?.connected ?? false;

  Stream<Map<String, dynamic>> get locationStream => _locationController.stream;

  Future<void> connect() async {
    // Configurar listeners de red
    _setupNetworkListener();
    
    await _initSocketConnection();
    return _connectionCompleter.future;
  }

  Future<void> _initSocketConnection() async {
    _socket = IO.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'reconnection': true,
      'reconnectionAttempts': 5,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
    });

    _socket!.connect();

    _setupSocketListeners();
  }

  void _setupNetworkListener() {
    final connectivity = Connectivity();
    _networkSubscription = connectivity.onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none && !isConnected && _shouldReconnect) {
        print('🔄 Intentando reconectar debido a cambio de red...');
        await _reconnect();
      }
    });
  }

  Future<void> _reconnect() async {
    try {
      _socket?.disconnect();
      await Future.delayed(Duration(seconds: 1));
      await _initSocketConnection();
    } catch (e) {
      print('Error al reconectar: $e');
    }
  }

  void _setupSocketListeners() {
    _socket!.onConnect((_) {
      print('🟢 Conectado como ADMINISTRADOR');
      _locationController.add({'status': 'connected'});
      if (!_connectionCompleter.isCompleted) {
        _connectionCompleter.complete();
      }
    });

    _socket!.on('update_location', (data) {
      try {
        final driverId = data['driver_id'] as String;
        final lat = data['lat'] as double;
        final lng = data['lng'] as double;
        
        _driverPositions[driverId] = LatLng(lat, lng);
        
        _locationController.add({
          'driverCode': driverId,
          'latitude': lat,
          'longitude': lng,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('Error processing location update: $e');
      }
    });

    _socket!.onDisconnect((_) {
      print('🔴 Socket desconectado del servidor (admin)');
      _locationController.add({'status': 'disconnected'});
      if (!_connectionCompleter.isCompleted) {
        _connectionCompleter.completeError('Disconnected');
      }
      
      if (_shouldReconnect) {
        Future.delayed(Duration(seconds: 5), () => _reconnect());
      }
    });

    _socket!.onConnectError((err) {
      print('Connection error: $err');
      _locationController.addError(err);
      if (!_connectionCompleter.isCompleted) {
        _connectionCompleter.completeError(err);
      }
      
      if (_shouldReconnect) {
        Future.delayed(Duration(seconds: 5), () => _reconnect());
      }
    });
  }

  Map<String, LatLng> get driverPositions => _driverPositions;

  void disconnect() {
    _shouldReconnect = false;
    _socket?.disconnect();
    _networkSubscription?.cancel();
    _locationController.close();
  }
  
  void updateServerUrl(String newUrl) {
    _serverUrl = newUrl;
    if (isConnected) {
      _reconnect();
    }
  }
}