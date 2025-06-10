import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location.dart' as model;
import '../models/driver.dart';
import '../database/location_dao.dart';
import '../database/driver_dao.dart';
import '../providers/gps_provider.dart';
import '../services/realtime_service.dart';
import '../services/admin_tracking_service.dart';

class MapScreen extends StatefulWidget {
  final bool isDriver;
  final Driver? focusDriver;
  final String? focusDriverCode;
  final String? serverUrl; // Agregar parámetro opcional

  const MapScreen({
    Key? key, 
    this.isDriver = false,
    this.focusDriver,
    this.focusDriverCode,
    this.serverUrl,
  }) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  Timer? _refreshTimer;
  final DriverDao _driverDao = DriverDao();
  final LocationDao _locationDao = LocationDao();
  bool _isLoading = false;
  Driver? _focusDriverFromCode;
  late AdminTrackingService _adminTrackingService;
  StreamSubscription<Map<String, dynamic>>? _adminLocationSubscription;
  bool _isAdminConnected = false;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  StreamSubscription<Map<String, dynamic>>? _locationSubscription;
  StreamSubscription<Map<String, dynamic>>? _alertSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _allDriversSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeFocusDriver();
    _configureServices(); // Nueva función para configurar servicios
    _setupRealtimeListeners();
    _startAutoRefresh();
    
    _adminTrackingService = AdminTrackingService();
    _connectAdminService();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateMarkers();
    });
  }

  void _configureServices() {
    // Configurar URL del servidor si se proporciona
    if (widget.serverUrl != null && widget.serverUrl!.isNotEmpty) {
      RealtimeService.instance.configureServer(widget.serverUrl!);
    }
  }

  Future<void> _connectAdminService() async {
    try {
      // Configurar URL del servidor para admin si se proporciona
      if (widget.serverUrl != null && widget.serverUrl!.isNotEmpty) {
        _adminTrackingService.updateServerUrl(widget.serverUrl!);
      }
      
      await _adminTrackingService.connect();
      if (mounted) {
        setState(() {
          _isAdminConnected = true;
        });
      }
      
      _adminLocationSubscription?.cancel();
      _adminLocationSubscription = _adminTrackingService.locationStream.listen(
        (locationData) {
          if (mounted) {
            _handleAdminLocationUpdate(locationData);
          }
        },
        onError: (error) {
          print('Error en admin location updates: $error');
          if (mounted) {
            setState(() {
              _isAdminConnected = false;
            });
          }
        },
      );
      
    } catch (error) {
      print('Error connecting to admin service: $error');
      if (mounted) {
        setState(() {
          _isAdminConnected = false;
        });
      }
      _handleConnectionError(error);
    }
  }

  void _handleAdminLocationUpdate(Map<String, dynamic> locationData) {
    try {
      final location = model.Location(
        id: 0,
        driverCode: locationData['driverCode'] ?? '',
        latitude: (locationData['latitude'] ?? 0.0).toDouble(),
        longitude: (locationData['longitude'] ?? 0.0).toDouble(),
        speed: (locationData['speed'] ?? 0.0).toDouble(),
        timestamp: DateTime.tryParse(locationData['timestamp'] ?? '') ?? DateTime.now(),
      );
      
      _updateSingleMarker(location);
    } catch (e) {
      print('Error procesando admin location update: $e');
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _pulseController.repeat(reverse: true);
  }

  void _setupRealtimeListeners() {
    final realtimeService = RealtimeService.instance;
    
    // Obtener código del conductor actual para la conexión
    final gpsProvider = Provider.of<GPSProvider>(context, listen: false);
    final currentDriver = gpsProvider.currentDriver;
    final driverCode = currentDriver?.code;
    
    realtimeService.connect(driverCode: driverCode);
    
    _locationSubscription = realtimeService.locationUpdates.listen(
      (locationData) {
        if (mounted) {
          _handleLocationUpdate(locationData);
        }
      },
      onError: (error) {
        print('Error en location updates: $error');
      },
    );
    
    _alertSubscription = realtimeService.geofenceAlerts.listen(
      (alert) {
        if (mounted) {
          _showGeofenceAlert(alert);
        }
      },
      onError: (error) {
        print('Error en geofence alerts: $error');
      },
    );

    _allDriversSubscription = realtimeService.allDriversUpdates.listen(
      (driversData) {
        if (mounted) {
          _handleAllDriversUpdate(driversData);
        }
      },
      onError: (error) {
        print('Error en all drivers updates: $error');
      },
    );
  }

  Future<void> _initializeFocusDriver() async {
    if (widget.focusDriverCode != null && widget.focusDriver == null) {
      try {
        final driverMap = await _driverDao.getDriverByCode(widget.focusDriverCode!);
        if (driverMap != null && mounted) {
          setState(() {
            _focusDriverFromCode = Driver.fromMap(driverMap);
          });
        }
      } catch (e) {
        print('Error loading driver by code: $e');
      }
    }
  }

  Driver? get focusDriver => widget.focusDriver ?? _focusDriverFromCode;

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isLoading && mounted) {
        _updateMarkers();
      }
    });
  }

  void _handleLocationUpdate(Map<String, dynamic> locationData) {
    try {
      final location = model.Location(
        id: 0,
        driverCode: locationData['driverCode'] ?? '',
        latitude: (locationData['latitude'] ?? 0.0).toDouble(),
        longitude: (locationData['longitude'] ?? 0.0).toDouble(),
        speed: (locationData['speed'] ?? 0.0).toDouble(),
        timestamp: DateTime.tryParse(locationData['timestamp'] ?? '') ?? DateTime.now(),
      );
      
      _updateSingleMarker(location);
    } catch (e) {
      print('Error procesando location update: $e');
    }
  }

  void _handleAllDriversUpdate(List<Map<String, dynamic>> driversData) {
    print('Recibidos ${driversData.length} conductores del servidor');
    
    if (!_isLoading) {
      _updateMarkers();
    }
  }

  void _updateSingleMarker(model.Location location) {
    final driverCode = location.driverCode;
    if (driverCode == null) return;
    
    setState(() {
      final existingIndex = _markers.indexWhere(
        (marker) => marker.key == Key(driverCode),
      );
      
      if (existingIndex != -1) {
        _driverDao.getDriverByCode(driverCode).then((driverMap) {
          if (driverMap != null && mounted) {
            final driver = Driver.fromMap(driverMap);
            final updatedMarker = _createMarker(location, driver);
            
            setState(() {
              _markers[existingIndex] = updatedMarker;
            });
          }
        });
      } else {
        _driverDao.getDriverByCode(driverCode).then((driverMap) {
          if (driverMap != null && mounted) {
            final driver = Driver.fromMap(driverMap);
            final newMarker = _createMarker(location, driver);
            
            setState(() {
              _markers.add(newMarker);
            });
          }
        });
      }
    });
  }

  void _showGeofenceAlert(Map<String, dynamic> alert) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Alerta: ${alert['message'] ?? 'Conductor fuera de zona'}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () {
            if (alert['driverCode'] != null) {
              _centerOnDriverByCode(alert['driverCode']);
            }
          },
        ),
      ),
    );
  }

  Future<void> _centerOnDriverByCode(String driverCode) async {
    try {
      final lastLocation = await _locationDao.getLastLocation(driverCode);
      if (lastLocation != null && mounted) {
        _mapController.move(
          LatLng(lastLocation.latitude, lastLocation.longitude), 
          16.0
        );
      }
    } catch (e) {
      print('Error centering on driver: $e');
    }
  }

  Future<void> _updateMarkers() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    final gpsProvider = Provider.of<GPSProvider>(context, listen: false);
    final currentDriver = gpsProvider.currentDriver;

    List<Marker> newMarkers = [];

    try {
      if (focusDriver != null) {
        final lastLocation = await _locationDao.getLastLocation(focusDriver!.code);
        if (lastLocation != null) {
          newMarkers.add(_createMarker(lastLocation, focusDriver!));
          _mapController.move(
            LatLng(lastLocation.latitude, lastLocation.longitude), 
            15.0
          );
        }
      }
      else if (widget.isDriver && currentDriver != null) {
        final lastLocation = await _locationDao.getLastLocation(currentDriver.code);
        if (lastLocation != null) {
          newMarkers.add(_createMarker(lastLocation, currentDriver));
        }
      }
      else {
        await _loadAllActiveDrivers(newMarkers);
      }

      if (mounted) {
        setState(() {
          _markers = newMarkers;
        });
        RealtimeService.instance.requestAllDrivers();
      }
    } catch (e) {
      print('Error updating markers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error actualizando marcadores: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadAllActiveDrivers(List<Marker> newMarkers) async {
    try {
      final allDriverMaps = await _driverDao.getAllDrivers();
      final allDrivers = allDriverMaps.map((map) => Driver.fromMap(map)).toList();
      final activeDrivers = allDrivers.where((driver) => driver.isActive).toList();

      for (final driver in activeDrivers) {
        final lastLocation = await _locationDao.getLastLocation(driver.code);
        if (lastLocation != null) {
          final timeDifference = DateTime.now().difference(lastLocation.timestamp);
          if (timeDifference.inMinutes <= 30) {
            newMarkers.add(_createMarker(lastLocation, driver));
          }
        }
      }
    } catch (e) {
      print('Error loading active drivers: $e');
    }
  }

  bool _isCurrentUserDriver(Driver driver) {
    final gpsProvider = Provider.of<GPSProvider>(context, listen: false);
    final currentDriver = gpsProvider.currentDriver;
    return currentDriver != null && currentDriver.code == driver.code;
  }

  IconData _getCarIcon(Driver driver) {
    final isCurrentUser = _isCurrentUserDriver(driver);
    return isCurrentUser ? Icons.navigation : Icons.local_taxi;
  }

  Widget _buildPulseEffect(Color color) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = 1.0 + (_pulseAnimation.value * 0.3);
        final opacity = 1.0 - _pulseAnimation.value;
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(opacity * 0.6),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Marker _createMarker(model.Location location, Driver driver) {
    final markerColor = _getMarkerColor(driver, location);
    final isCurrentUser = _isCurrentUserDriver(driver);
    final timeDifference = DateTime.now().difference(location.timestamp);
    final isOnline = timeDifference.inMinutes <= 5;

    return Marker(
      key: Key(driver.code),
      point: LatLng(location.latitude, location.longitude),
      width: isCurrentUser ? 80 : 50,
      height: isCurrentUser ? 80 : 50,
      child: GestureDetector(
        onTap: () => _showDriverInfo(driver, location),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isCurrentUser && isOnline)
              _buildPulseEffect(markerColor),
            
            Positioned(
              left: 2,
              top: 2,
              child: Container(
                width: isCurrentUser ? 48 : 40,
                height: isCurrentUser ? 48 : 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            Container(
              width: isCurrentUser ? 46 : 38,
              height: isCurrentUser ? 46 : 38,
              decoration: BoxDecoration(
                color: markerColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrentUser ? Colors.white : Colors.grey.shade300, 
                  width: isCurrentUser ? 3 : 2
                ),
                boxShadow: [
                  BoxShadow(
                    color: markerColor.withOpacity(0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    _getCarIcon(driver),
                    color: Colors.white,
                    size: isCurrentUser ? 22 : 18,
                    shadows: const [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 2,
                        color: Colors.black54,
                      ),
                    ],
                  ),
                  
                  if (isOnline)
                    Positioned(
                      top: 3,
                      right: 3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.lightGreenAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMarkerColor(Driver driver, model.Location location) {
    final isCurrentUser = _isCurrentUserDriver(driver);
    
    if (isCurrentUser) {
      return Colors.blue.shade700;
    }
    
    if (focusDriver != null && driver.code == focusDriver!.code) {
      return Colors.red.shade600;
    }

    final timeDifference = DateTime.now().difference(location.timestamp);
    
    if (timeDifference.inMinutes <= 5) {
      return Colors.green.shade600;
    } else if (timeDifference.inMinutes <= 15) {
      return Colors.orange.shade600;
    } else {
      return Colors.grey.shade500;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 30) {
      return 'Ahora';
    } else if (difference.inMinutes < 1) {
      return 'Hace ${difference.inSeconds}s';
    } else if (difference.inHours < 1) {
      return 'Hace ${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return 'Hace ${difference.inHours}h';
    } else {
      return 'Hace ${difference.inDays}d';
    }
  }

  void _showDriverInfo(Driver driver, model.Location location) {
    final timeDifference = DateTime.now().difference(location.timestamp);
    final isOnline = timeDifference.inMinutes <= 5;
    final isCurrentUser = _isCurrentUserDriver(driver);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getMarkerColor(driver, location).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCarIcon(driver),
                      color: _getMarkerColor(driver, location),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.name,
                          style: const TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isCurrentUser)
                          Text(
                            'Tu vehículo',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isOnline ? 'EN LÍNEA' : 'DESCONECTADO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              _buildInfoCard([
                _buildInfoRow(Icons.code, 'Código', driver.code),
                _buildInfoRow(Icons.credit_card, 'Cédula', driver.idNumber),
                _buildInfoRow(Icons.directions_car, 'Placa', driver.plateNumber),
              ]),
              
              const SizedBox(height: 12),
              
              _buildInfoCard([
                _buildInfoRow(Icons.speed, 'Velocidad', '${location.speed.toStringAsFixed(1)} km/h'),
                _buildInfoRow(Icons.location_on, 'Coordenadas', 
                  '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}'),
                _buildInfoRow(Icons.access_time, 'Última actualización', _getTimeAgo(location.timestamp)),
              ]),
              
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _centerOnDriver(location);
                      },
                      icon: const Icon(Icons.my_location),
                      label: const Text('Centrar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (!isCurrentUser) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MapScreen(
                                focusDriver: driver,
                                serverUrl: widget.serverUrl, // Pasar URL del servidor
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_pin_circle),
                        label: const Text('Seguir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _centerOnDriver(model.Location location) {
    _mapController.move(
      LatLng(location.latitude, location.longitude), 
      17.0
    );
  }

  @override
  void dispose() {
    _adminLocationSubscription?.cancel();
    _adminTrackingService.disconnect();
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _locationSubscription?.cancel();
    _alertSubscription?.cancel();
    _allDriversSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gpsProvider = Provider.of<GPSProvider>(context);
    final position = gpsProvider.currentPosition;

    LatLng initialPosition;
    if (focusDriver != null && 
        focusDriver!.lastLatitude != null && 
        focusDriver!.lastLongitude != null) {
      initialPosition = LatLng(
        focusDriver!.lastLatitude!, 
        focusDriver!.lastLongitude!
      );
    } else if (position != null) {
      initialPosition = LatLng(position.latitude, position.longitude);
    } else {
      initialPosition = const LatLng(-0.2500000, -79.1666667);
    }

    String appBarTitle;
    IconData appBarIcon;
    if (focusDriver != null) {
      appBarTitle = 'Siguiendo - ${focusDriver!.name}';
      appBarIcon = Icons.person_pin_circle;
    } else if (widget.isDriver) {
      appBarTitle = 'Mi Ubicación';
      appBarIcon = Icons.navigation;
    } else {
      appBarTitle = 'Mapa de Conductores';
      appBarIcon = Icons.map;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(appBarIcon, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(appBarTitle)),
          ],
        ),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _updateMarkers,
            tooltip: 'Actualizar marcadores',
          ),
          
          if (focusDriver != null)
            IconButton(
              icon: const Icon(Icons.my_location),
              tooltip: 'Centrar en conductor',
              onPressed: () async {
                final lastLocation = await _locationDao.getLastLocation(focusDriver!.code);
                if (lastLocation != null) {
                  _centerOnDriver(lastLocation);
                }
              },
            ),
          
          if (widget.isDriver)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Salir',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirmar salida'),
                    content: const Text('¿Estás seguro de que quieres salir? Se detendrá el seguimiento GPS.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          gpsProvider.stopTracking();
                          Navigator.pop(context);
                        },
                        child: const Text('Salir'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  focusDriver != null 
                    ? Icons.person_pin_circle 
                    : Icons.map,
                  color: Colors.blue.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    focusDriver != null
                      ? 'Siguiendo a ${focusDriver!.name}'
                      : 'Mostrando conductores activos',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                if (_markers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_markers.length}',style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (_isAdminConnected)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ADMIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialPosition,
                initialZoom: focusDriver != null ? 15.0 : 12.0,
                minZoom: 8.0,
                maxZoom: 18.0,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.gps_tracker',
                  maxZoom: 18,
                  tileProvider: NetworkTileProvider(),
                ),
                MarkerLayer(
                  markers: _markers,
                ),
                if (position != null && !widget.isDriver)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(position.latitude, position.longitude),
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.purple.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_pin,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (position != null && !widget.isDriver)
            FloatingActionButton.small(
              heroTag: "myLocation",
              onPressed: () {
                _mapController.move(
                  LatLng(position.latitude, position.longitude),
                  15.0,
                );
              },
              backgroundColor: Colors.purple.shade600,
              child: const Icon(Icons.person_pin, color: Colors.white),
              tooltip: 'Mi ubicación',
            ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: "refresh",
            onPressed: _isLoading ? null : _updateMarkers,
            backgroundColor: _isLoading ? Colors.grey : Colors.blue.shade600,
            child: _isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualizar marcadores',
          ),
        ],
      ),
    );
  }

  void _handleConnectionError(dynamic error) {
    if (!mounted) return;
    
    // Mostrar error de conexión de manera no intrusiva
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error de conexión al servidor: ${error.toString().substring(0, min(50, error.toString().length))}...'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Reintentar',
          onPressed: _connectAdminService,
        ),
      ),
    );
  }
}