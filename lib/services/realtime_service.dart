import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import '../models/location.dart' as model;
import '../models/driver.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  static RealtimeService get instance => _instance;
  
  RealtimeService._internal();
  
  IO.Socket? _socket;
  bool _isConnected = false;
  Timer? _heartbeatTimer;
  StreamSubscription? _networkSubscription;
  bool _shouldReconnect = true;
  
  // Controladores de streams para eventos
  final StreamController<Map<String, dynamic>> _locationUpdateController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _geofenceAlertController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _driverStatusController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<List<Map<String, dynamic>>> _allDriversController = 
      StreamController<List<Map<String, dynamic>>>.broadcast();
  
  // Streams públicos
  Stream<Map<String, dynamic>> get locationUpdates => _locationUpdateController.stream;
  Stream<Map<String, dynamic>> get geofenceAlerts => _geofenceAlertController.stream;
  Stream<Map<String, dynamic>> get driverStatusUpdates => _driverStatusController.stream;
  Stream<List<Map<String, dynamic>>> get allDriversUpdates => _allDriversController.stream;
  
  // Configuración del servidor
  String _serverUrl = 'http://tu-servidor.com:3000'; // Cambiar por tu servidor real
  String? _currentDriverCode;
  
  bool get isConnected => _isConnected;
  String? get currentDriverCode => _currentDriverCode;
  
  /// Configurar URL del servidor
  void configureServer(String url) {
    _serverUrl = url;
    if (_isConnected) {
      reconnect();
    }
  }
  
  /// Conectar al servidor Socket.IO con manejo de reconexión automática
  Future<void> connect({String? driverCode}) async {
    if (_isConnected) {
      print('⚠️ Socket ya está conectado');
      return;
    }
    
    try {
      _currentDriverCode = driverCode;
      _shouldReconnect = true;
      
      // Configurar listener de cambios de red
      _setupNetworkListener();
      
      _socket = IO.io(_serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'timeout': 20000,
        'forceNew': true,
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
      });
      
      _setupSocketListeners();
      
      _socket!.connect();
      
      print('🔄 Conectando a servidor de tiempo real: $_serverUrl');
      
      // Verificar conexión a internet antes de conectar
      final hasInternet = await InternetConnectionChecker().hasConnection;
      if (!hasInternet) {
        throw Exception('No hay conexión a internet');
      }
      
    } catch (e) {
      print('❌ Error conectando socket: $e');
      _isConnected = false;
      if (_shouldReconnect) {
        print('⚡ Intentando reconectar en 5 segundos...');
        await Future.delayed(Duration(seconds: 5));
        await connect(driverCode: driverCode);
      }
    }
  }
  
  /// Configurar listeners del socket
  void _setupSocketListeners() {
    if (_socket == null) return;
    
    // Evento de conexión exitosa
    _socket!.on('connect', (_) {
      print('✅ Socket conectado exitosamente');
      _isConnected = true;
      
      // Registrar conductor si está disponible
      if (_currentDriverCode != null) {
        _registerDriver(_currentDriverCode!);
      }
      
      // Iniciar heartbeat
      _startHeartbeat();
    });
    
    // Evento de desconexión
    _socket!.on('disconnect', (_) {
      print('🔌 Socket desconectado');
      _isConnected = false;
      _stopHeartbeat();
      
      if (_shouldReconnect) {
        print('⚡ Intentando reconectar en 5 segundos...');
        Future.delayed(Duration(seconds: 5), () => reconnect());
       
      
      }
    });
    
    // Error de conexión
    _socket!.on('connect_error', (error) {
      print('❌ Error de conexión: $error');
      _isConnected = false;
      
      if (_shouldReconnect) {
        print('⚡ Intentando reconectar en 5 segundos...');
        Future.delayed(Duration(seconds: 5), () => reconnect());
      }
    });
    
    // Actualizaciones de ubicación
    _socket!.on('location_update', (data) {
      print('📍 Ubicación recibida: $data');
      _locationUpdateController.add(Map<String, dynamic>.from(data));
    });
    
    // Alertas de geocerca
    _socket!.on('geofence_alert', (data) {
      print('🚨 Alerta de geocerca: $data');
      _geofenceAlertController.add(Map<String, dynamic>.from(data));
    });
    
    // Cambios de estado de conductores
    _socket!.on('driver_status_update', (data) {
      print('👤 Estado de conductor actualizado: $data');
      _driverStatusController.add(Map<String, dynamic>.from(data));
    });
    
    // Lista completa de conductores
    _socket!.on('all_drivers_update', (data) {
      print('👥 Conductores actualizados: ${data.length} conductores');
      if (data is List) {
        _allDriversController.add(List<Map<String, dynamic>>.from(
          data.map((item) => Map<String, dynamic>.from(item))
        ));
      }
    });
    
    // Confirmación de registro
    _socket!.on('driver_registered', (data) {
      print('✅ Conductor registrado: $data');
    });
    
    // Respuesta de heartbeat
    _socket!.on('pong', (_) {
      print('💓 Heartbeat recibido');
    });
  }
  
  /// Configurar listener de cambios de red
  void _setupNetworkListener() {
    final connectivity = Connectivity();
    _networkSubscription = connectivity.onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        final hasInternet = await InternetConnectionChecker().hasConnection;
        if (hasInternet && !_isConnected && _shouldReconnect) {
          print('🌐 Cambio de red detectado - Reconectando...');
          await reconnect();
        } else if (!hasInternet) {
          print('⚠️ Red disponible pero sin internet');
        }
      } else {
        print('📵 Sin conexión de red');
      }
    });
  }
  
  /// Registrar conductor en el servidor
  void _registerDriver(String driverCode) {
    if (!_isConnected || _socket == null) return;
    
    _getConnectionType().then((connectionType) {
      final driverData = {
        'driverCode': driverCode,
        'timestamp': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'connectionType': connectionType,
      };
      
      _socket!.emit('register_driver', driverData);
      print('📝 Registrando conductor: $driverCode');
    });
  }
  
  /// Obtener tipo de conexión actual
  Future<String> _getConnectionType() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    
    switch (result) {
      case ConnectivityResult.wifi:
        return 'wifi';
      case ConnectivityResult.mobile:
        return 'mobile';
      case ConnectivityResult.ethernet:
        return 'ethernet';
      case ConnectivityResult.vpn:
        return 'vpn';
      default:
        return 'none';
    }
  }
  
  /// Enviar actualización de ubicación
  void sendLocationUpdate(model.Location location) {
    if (!_isConnected || _socket == null) {
      print('⚠️ Socket no conectado, no se puede enviar ubicación');
      return;
    }
    
    _getConnectionType().then((connectionType) {
      final locationData = {
        'driverCode': location.driverCode,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'speed': location.speed,
        'timestamp': location.timestamp.toIso8601String(),
        'accuracy': 5.0,
        'connectionType': connectionType,
      };
      
      _socket!.emit('location_update', locationData);
      print('📍 Ubicación enviada: ${location.driverCode} - ${location.latitude}, ${location.longitude}');
    });
  }
  
  /// Enviar alerta de geocerca
  void sendGeofenceAlert(Map<String, dynamic> alertData) {
    if (!_isConnected || _socket == null) {
      print('⚠️ Socket no conectado, no se puede enviar alerta');
      return;
    }
    
    _getConnectionType().then((connectionType) {
      alertData['connectionType'] = connectionType;
      _socket!.emit('geofence_alert', alertData);
      print('🚨 Alerta de geocerca enviada: ${alertData['type']}');
    });
  }
  
  /// Enviar cambio de estado de conductor
  void sendDriverStatusUpdate(String driverCode, String status) {
    if (!_isConnected || _socket == null) {
      print('⚠️ Socket no conectado, no se puede enviar estado');
      return;
    }
    
    _getConnectionType().then((connectionType) {
      final statusData = {
        'driverCode': driverCode,
        'status': status,
        'timestamp': DateTime.now().toIso8601String(),
        'connectionType': connectionType,
      };
      
      _socket!.emit('driver_status_update', statusData);
      print('👤 Estado de conductor enviado: $driverCode -> $status');
    });
  }
  
  /// Solicitar lista de todos los conductores conectados
  void requestAllDrivers() {
    if (!_isConnected || _socket == null) {
      print('⚠️ Socket no conectado, no se puede solicitar conductores');
      return;
    }
    
    _socket!.emit('get_all_drivers');
    print('👥 Solicitando lista de conductores');
  }
  
  /// Iniciar heartbeat para mantener conexión
  void _startHeartbeat() {
    _stopHeartbeat(); // Detener heartbeat existente
    
    _heartbeatTimer = Timer.periodic(Duration(seconds: 30), (timer) {
      if (_isConnected && _socket != null) {
        _getConnectionType().then((connectionType) {
          _socket!.emit('ping', {
            'timestamp': DateTime.now().toIso8601String(),
            'connectionType': connectionType,
          });
          print('💓 Enviando heartbeat');
        });
      }
    });
  }
  
  /// Detener heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  /// Unirse a un canal específico
  void joinChannel(String channelName) {
    if (!_isConnected || _socket == null) return;
    
    _getConnectionType().then((connectionType) {
      _socket!.emit('join_channel', {
        'channel': channelName,
        'connectionType': connectionType,
      });
      print('🔗 Uniéndose al canal: $channelName');
    });
  }
  
  /// Salir de un canal
  void leaveChannel(String channelName) {
    if (!_isConnected || _socket == null) return;
    
    _socket!.emit('leave_channel', {'channel': channelName});
    print('🚪 Saliendo del canal: $channelName');
  }
  
  /// Desconectar socket
  void disconnect() {
    _shouldReconnect = false;
    _stopHeartbeat();
    _networkSubscription?.cancel();
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      _currentDriverCode = null;
      print('🔌 Socket desconectado manualmente');
    }
  }
  
  /// Reconectar automáticamente
  Future<void> reconnect() async {
    if (!_shouldReconnect) return;
    
    print('🔄 Intentando reconectar...');
    disconnect();
    await Future.delayed(Duration(seconds: 2));
    await connect(driverCode: _currentDriverCode);
  }
  
  /// Verificar estado de la conexión
  bool checkConnection() {
    return _isConnected && _socket != null && _socket!.connected;
  }
  
  /// Limpiar recursos
  void dispose() {
    disconnect();
    _locationUpdateController.close();
    _geofenceAlertController.close();
    _driverStatusController.close();
    _allDriversController.close();
  }
}