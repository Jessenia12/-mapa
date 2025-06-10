// lib/services/driver_tracking_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class DriverTrackingService {
  IO.Socket? _socket;
  Stream<Position>? _positionStream;

  void start(String driverId) async {
    await _checkPermissions();

    _socket = IO.io('http://localhost:3000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    _socket!.connect();

    _socket!.onConnect((_) {
      print('🟢 Conectado al servidor como DRIVER');
      _listenToLocation(driverId);
    });

    _socket!.onDisconnect((_) => print('🔴 Socket desconectado'));
  }

  void _listenToLocation(String driverId) {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    );

    _positionStream!.listen((position) {
      _socket?.emit('update_location', {
        'driver_id': driverId,
        'lat': position.latitude,
        'lng': position.longitude,
      });
    });
  }

  Future<void> _checkPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('El GPS está desactivado');
    }
  }

  void dispose() {
    _socket?.disconnect();
  }
}
