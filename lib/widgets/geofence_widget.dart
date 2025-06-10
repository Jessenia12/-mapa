import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../utils/location_utils.dart'; // Asegúrate que este archivo y clase existen

class GeofenceWidget extends StatefulWidget {
  final List<Geofence> geofences;
  final LatLng? initialCenter;
  final double initialZoom;
  final VoidCallback? onAddGeofence;
  final Function(Geofence)? onEditGeofence;
  final Function(Geofence)? onDeleteGeofence;
  final String? socketUrl;

  const GeofenceWidget({
    Key? key,
    required this.geofences,
    this.initialCenter,
    this.initialZoom = 13.0,
    this.onAddGeofence,
    this.onEditGeofence,
    this.onDeleteGeofence,
    this.socketUrl,
  }) : super(key: key);

  @override
  State<GeofenceWidget> createState() => _GeofenceWidgetState();
}

class _GeofenceWidgetState extends State<GeofenceWidget> {
  final MapController _mapController = MapController();
  Geofence? _selectedGeofence;
  List<CircleMarker> _circles = [];
  List<Marker> _markers = [];
  IO.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _updateMapElements();
    _initializeSocket();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GeofenceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.geofences != widget.geofences) {
      _updateMapElements();
    }
    if (oldWidget.socketUrl != widget.socketUrl) {
      _initializeSocket();
    }
  }

  void _initializeSocket() {
    if (widget.socketUrl != null && widget.socketUrl!.isNotEmpty) {
      _socket?.dispose();

      _socket = IO.io(widget.socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
      });

      _socket!.connect();

      _socket!.on('connect', (_) {
        print('Conectado al servidor Socket.IO');
      });

      _socket!.on('disconnect', (_) {
        print('Desconectado del servidor Socket.IO');
      });

      _socket!.on('geofence_event', (data) {
        _handleGeofenceEvent(data);
      });

      _socket!.on('location_update', (data) {
        _handleLocationUpdate(data);
      });
    }
  }

  void _handleGeofenceEvent(dynamic data) {
    print('Evento de geocerca recibido: $data');
  }

  void _handleLocationUpdate(dynamic data) {
    print('Actualización de ubicación: $data');
  }

  void _updateMapElements() {
    setState(() {
      _circles = _buildCircles();
      _markers = _buildMarkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMap(),
          _buildTopControls(),
          if (_selectedGeofence != null) _buildGeofenceInfo(),
        ],
      ),
      floatingActionButton: widget.onAddGeofence != null
          ? FloatingActionButton(
              onPressed: widget.onAddGeofence,
              child: Icon(Icons.add_location),
              tooltip: 'Agregar Geocerca',
            )
          : null,
    );
  }

  Widget _buildMap() {
    LatLng initialPosition = widget.initialCenter ??
        (widget.geofences.isNotEmpty &&
                widget.geofences.first.centerLatitude != null &&
                widget.geofences.first.centerLongitude != null
            ? LatLng(widget.geofences.first.centerLatitude!,
                widget.geofences.first.centerLongitude!)
            : LatLng(-0.2298500, -78.5249500)); // Coordenadas por defecto

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: initialPosition,
        zoom: widget.initialZoom,
        onTap: (tapPosition, point) {
          setState(() {
            _selectedGeofence = null;
          });
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.app',
        ),
        CircleLayer(circles: _circles),
        MarkerLayer(markers: _markers),
      ],
    );
  }

  Widget _buildTopControls() {
    return Positioned(
      top: 50,
      left: 16,
      right: 16,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Geocercas: ${widget.geofences.length}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Spacer(),
              _buildConnectionStatus(),
              SizedBox(width: 8),
              _buildLegend(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    if (_socket == null) return SizedBox.shrink();

    bool isConnected = _socket!.connected;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isConnected ? Colors.green : Colors.red,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(
          isConnected ? 'En línea' : 'Desconectado',
          style: TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLegendItem(Colors.red, 'Restringida'),
        SizedBox(width: 8),
        _buildLegendItem(Colors.green, 'Segura'),
        SizedBox(width: 8),
        _buildLegendItem(Colors.orange, 'Checkpoint'),
        SizedBox(width: 8),
        _buildLegendItem(Colors.purple, 'Poligonal'),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            border: Border.all(color: color),
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildGeofenceInfo() {
    if (_selectedGeofence == null) return SizedBox.shrink();

    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Card(
        elevation: 8,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getGeofenceIcon(_selectedGeofence!.type),
                    color: _getGeofenceColor(_selectedGeofence!.type),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedGeofence!.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _selectedGeofence = null;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(_selectedGeofence!.description),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedGeofence!.radius != null)
                          Text(
                              'Radio: ${_selectedGeofence!.radius!.toStringAsFixed(0)}m'),
                        Text(
                            'Tipo: ${_getGeofenceTypeName(_selectedGeofence!.type)}'),
                        Text(
                            'Estado: ${_selectedGeofence!.isActive ? "Activa" : "Inactiva"}'),
                        Text(
                            'Alerta entrada: ${_selectedGeofence!.alertOnEntry ? "Sí" : "No"}'),
                        Text(
                            'Alerta salida: ${_selectedGeofence!.alertOnExit ? "Sí" : "No"}'),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (widget.onEditGeofence != null)
                        IconButton(
                          icon: Icon(Icons.edit),
                          onPressed: () =>
                              widget.onEditGeofence!(_selectedGeofence!),
                        ),
                      if (widget.onDeleteGeofence != null)
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _showDeleteConfirmation(),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<CircleMarker> _buildCircles() {
    return widget.geofences
        .where((geofence) =>
            geofence.isActive &&
            geofence.type == GeofenceType.circular &&
            geofence.centerLatitude != null &&
            geofence.centerLongitude != null &&
            geofence.radius != null)
        .map((geofence) {
      return CircleMarker(
        point: LatLng(geofence.centerLatitude!, geofence.centerLongitude!),
        radius: geofence.radius!,
        color: _getGeofenceColor(geofence.type).withOpacity(0.3),
        borderColor: _getGeofenceColor(geofence.type),
        borderStrokeWidth: 2.0,
        useRadiusInMeter: true,
      );
    }).toList();
  }

  List<Marker> _buildMarkers() {
    return widget.geofences
        .where((geofence) =>
            geofence.isActive &&
            geofence.centerLatitude != null &&
            geofence.centerLongitude != null)
        .map((geofence) {
      return Marker(
        point: LatLng(geofence.centerLatitude!, geofence.centerLongitude!),
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedGeofence = geofence;
            });
          },
          child: Icon(
            Icons.location_pin,
            color: _getGeofenceColor(geofence.type),
            size: 40,
          ),
        ),
      );
    }).toList();
  }

  Color _getGeofenceColor(GeofenceType type) {
    switch (type) {
      case GeofenceType.restricted:
        return Colors.red;
      case GeofenceType.safe:
        return Colors.green;
      case GeofenceType.checkpoint:
        return Colors.orange;
      case GeofenceType.polygonal:
        return Colors.purple;
      case GeofenceType.circular:
        return Colors.blue;
    }
  }

  IconData _getGeofenceIcon(GeofenceType type) {
    switch (type) {
      case GeofenceType.restricted:
        return Icons.warning;
      case GeofenceType.safe:
        return Icons.security;
      case GeofenceType.checkpoint:
        return Icons.flag;
      case GeofenceType.polygonal:
        return Icons.pentagon;
      case GeofenceType.circular:
        return Icons.circle;
    }
  }

  String _getGeofenceTypeName(GeofenceType type) {
    switch (type) {
      case GeofenceType.restricted:
        return 'Zona Restringida';
      case GeofenceType.safe:
        return 'Zona Segura';
      case GeofenceType.checkpoint:
        return 'Punto de Control';
      case GeofenceType.polygonal:
        return 'Geocerca Poligonal';
      case GeofenceType.circular:
        return 'Geocerca Circular';
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Eliminar Geocerca'),
          content: Text(
              '¿Estás seguro de que quieres eliminar "${_selectedGeofence!.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.onDeleteGeofence!(_selectedGeofence!);
                setState(() {
                  _selectedGeofence = null;
                });
              },
              child: Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void sendGeofenceEvent(String eventType, Geofence geofence) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('geofence_event', {
        'type': eventType,
        'geofence': {
          'id': geofence.id,
          'name': geofence.name,
          'type': geofence.type.toString(),
          'centerLatitude': geofence.centerLatitude,
          'centerLongitude': geofence.centerLongitude,
          'radius': geofence.radius,
          'isActive': geofence.isActive,
        },
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  void sendLocationUpdate(double latitude, double longitude) {
    if (_socket != null && _socket!.connected) {
      _socket!.emit('location_update', {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }
}