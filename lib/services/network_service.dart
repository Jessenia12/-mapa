// lib/services/network_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

class NetworkService {
  final Connectivity _connectivity = Connectivity();
  final InternetConnectionChecker _connectionChecker = InternetConnectionChecker();

  Stream<NetworkStatus> get networkStatusStream async* {
    yield* _connectivity.onConnectivityChanged.asyncMap((results) async {
      // Tomamos el primer resultado o usamos none si la lista está vacía
      final result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      return await _getNetworkStatus(result);
    });
  }

  Future<NetworkStatus> _getNetworkStatus(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      return NetworkStatus.disconnected;
    }
    
    final hasInternet = await _connectionChecker.hasConnection;
    return hasInternet ? NetworkStatus.connected : NetworkStatus.disconnected;
  }

  Future<bool> isConnected() async {
    final connectivityResults = await _connectivity.checkConnectivity();
    // Tomamos el primer resultado o usamos none si la lista está vacía
    final result = connectivityResults.isNotEmpty ? connectivityResults.first : ConnectivityResult.none;
    if (result == ConnectivityResult.none) {
      return false;
    }
    return await _connectionChecker.hasConnection;
  }
}

enum NetworkStatus {
  connected,
  disconnected,
}