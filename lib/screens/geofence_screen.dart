import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../database/geofence_dao.dart';
import '../models/geofence.dart';

// Clase simple para representar coordenadas
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  String toString() => 'LatLng($latitude, $longitude)';
}

// Widget personalizado para el mapa sin dependencias externas
class SimpleMapWidget extends StatefulWidget {
  final Function(LatLng)? onTap;
  final List<CircleGeofence> circles;
  final List<PolygonGeofence> polygons;
  final List<LatLng> tempPolygonPoints;
  final LatLng? circleCenter;

  const SimpleMapWidget({
    super.key,
    this.onTap,
    this.circles = const [],
    this.polygons = const [],
    this.tempPolygonPoints = const [],
    this.circleCenter,
  });

  @override
  State<SimpleMapWidget> createState() => _SimpleMapWidgetState();
}

class _SimpleMapWidgetState extends State<SimpleMapWidget> {
  double _zoom = 1.0;
  Offset _center = const Offset(0, 0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        if (widget.onTap != null) {
          // Convertir posición de tap a coordenadas lat/lng simuladas
          final size = MediaQuery.of(context).size;
          final x = (details.localPosition.dx - size.width / 2) / 100;
          final y = (details.localPosition.dy - size.height / 2) / 100;
          widget.onTap!(LatLng(-y, x)); // Simulación de coordenadas
        }
      },
      onScaleUpdate: (details) {
        setState(() {
          _zoom = math.max(0.5, math.min(3.0, _zoom * details.scale));
        });
      },
      onPanUpdate: (details) {
        setState(() {
          _center += details.delta;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade100,
              Colors.green.shade100,
            ],
          ),
        ),
        child: CustomPaint(
          painter: MapPainter(
            circles: widget.circles,
            polygons: widget.polygons,
            tempPolygonPoints: widget.tempPolygonPoints,
            circleCenter: widget.circleCenter,
            zoom: _zoom,
            center: _center,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class CircleGeofence {
  final String id;
  final LatLng center;
  final double radius;
  final Color color;

  CircleGeofence({
    required this.id,
    required this.center,
    required this.radius,
    this.color = Colors.blue,
  });
}

class PolygonGeofence {
  final String id;
  final List<LatLng> points;
  final Color color;

  PolygonGeofence({
    required this.id,
    required this.points,
    this.color = Colors.red,
  });
}

class MapPainter extends CustomPainter {
  final List<CircleGeofence> circles;
  final List<PolygonGeofence> polygons;
  final List<LatLng> tempPolygonPoints;
  final LatLng? circleCenter;
  final double zoom;
  final Offset center;

  MapPainter({
    required this.circles,
    required this.polygons,
    required this.tempPolygonPoints,
    this.circleCenter,
    required this.zoom,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Dibujar grid de fondo (simula calles)
    paint.color = Colors.grey.shade300;
    paint.strokeWidth = 1;
    
    for (int i = 0; i < size.width.toInt(); i += 50) {
      canvas.drawLine(
        Offset(i.toDouble(), 0),
        Offset(i.toDouble(), size.height),
        paint,
      );
    }
    
    for (int i = 0; i < size.height.toInt(); i += 50) {
      canvas.drawLine(
        Offset(0, i.toDouble()),
        Offset(size.width, i.toDouble()),
        paint,
      );
    }

    // Dibujar círculos guardados
    for (final circle in circles) {
      final centerX = size.width / 2 + circle.center.longitude * 100 * zoom + center.dx;
      final centerY = size.height / 2 - circle.center.latitude * 100 * zoom + center.dy;
      
      // Área del círculo
      paint.color = circle.color.withOpacity(0.2);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(centerX, centerY),
        circle.radius * zoom / 5,
        paint,
      );
      
      // Borde del círculo
      paint.color = circle.color;
      paint.strokeWidth = 2;
      paint.style = PaintingStyle.stroke;
      canvas.drawCircle(
        Offset(centerX, centerY),
        circle.radius * zoom / 5,
        paint,
      );
    }

    // Dibujar círculo temporal (mientras se está creando)
    if (circleCenter != null) {
      final centerX = size.width / 2 + circleCenter!.longitude * 100 * zoom + center.dx;
      final centerY = size.height / 2 - circleCenter!.latitude * 100 * zoom + center.dy;
      
      // Área del círculo temporal
      paint.color = Colors.orange.withOpacity(0.3);
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(centerX, centerY),
        200 * zoom / 5, // Radio por defecto
        paint,
      );
      
      // Borde del círculo temporal
      paint.color = Colors.orange;
      paint.strokeWidth = 2;
      paint.style = PaintingStyle.stroke;
      canvas.drawCircle(
        Offset(centerX, centerY),
        200 * zoom / 5,
        paint,
      );
    }

    // Dibujar polígonos guardados
    for (final polygon in polygons) {
      if (polygon.points.length < 3) continue;
      
      final path = Path();
      bool first = true;
      
      for (final point in polygon.points) {
        final x = size.width / 2 + point.longitude * 100 * zoom + center.dx;
        final y = size.height / 2 - point.latitude * 100 * zoom + center.dy;
        
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      
      // Área del polígono
      paint.color = polygon.color.withOpacity(0.2);
      paint.style = PaintingStyle.fill;
      canvas.drawPath(path, paint);
      
      // Borde del polígono
      paint.color = polygon.color;
      paint.strokeWidth = 2;
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }

    // Dibujar puntos temporales del polígono en construcción
    for (int i = 0; i < tempPolygonPoints.length; i++) {
      final point = tempPolygonPoints[i];
      final x = size.width / 2 + point.longitude * 100 * zoom + center.dx;
      final y = size.height / 2 - point.latitude * 100 * zoom + center.dy;
      
      // Punto
      paint.color = Colors.purple;
      paint.style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 6, paint);
      
      // Línea al siguiente punto
      if (i < tempPolygonPoints.length - 1) {
        final nextPoint = tempPolygonPoints[i + 1];
        final nextX = size.width / 2 + nextPoint.longitude * 100 * zoom + center.dx;
        final nextY = size.height / 2 - nextPoint.latitude * 100 * zoom + center.dy;
        
        paint.color = Colors.purple;
        paint.strokeWidth = 2;
        paint.style = PaintingStyle.stroke;
        canvas.drawLine(Offset(x, y), Offset(nextX, nextY), paint);
      }
    }

    // Línea de cierre del polígono temporal (si hay 3 o más puntos)
    if (tempPolygonPoints.length >= 3) {
      final firstPoint = tempPolygonPoints.first;
      final lastPoint = tempPolygonPoints.last;
      
      final firstX = size.width / 2 + firstPoint.longitude * 100 * zoom + center.dx;
      final firstY = size.height / 2 - firstPoint.latitude * 100 * zoom + center.dy;
      final lastX = size.width / 2 + lastPoint.longitude * 100 * zoom + center.dx;
      final lastY = size.height / 2 - lastPoint.latitude * 100 * zoom + center.dy;
      
      paint.color = Colors.purple.withOpacity(0.5);
      paint.strokeWidth = 1;
      paint.style = PaintingStyle.stroke;
      canvas.drawLine(Offset(lastX, lastY), Offset(firstX, firstY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GeofenceScreen extends StatefulWidget {
  const GeofenceScreen({super.key});

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  final List<Geofence> _geofences = [];
  List<CircleGeofence> _circles = [];
  List<PolygonGeofence> _polygons = [];
  List<LatLng> _tempPolygonPoints = [];
  LatLng? _circleCenter;
  final double _radius = 200;
  bool _isDrawingPolygon = false;
  bool _isAddingCircle = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGeofences();
  }

  Future<void> _loadGeofences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dao = GeofenceDao();
      final geos = await dao.getAllGeofences();
      setState(() {
        _geofences.clear();
        _geofences.addAll(geos);
        _drawGeofences();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar geocercas: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _drawGeofences() {
    _circles.clear();
    _polygons.clear();

    for (var g in _geofences) {
      if (g.type == 'circle' && g.centerLat != null && g.centerLng != null) {
        _circles.add(
          CircleGeofence(
            id: g.id.toString(),
            center: LatLng(g.centerLat!, g.centerLng!),
            radius: g.radius ?? 100,
            color: Colors.blue,
          ),
        );
      } else if (g.type == 'polygon' && g.polygonPoints != null && g.polygonPoints!.isNotEmpty) {
        _polygons.add(
          PolygonGeofence(
            id: g.id.toString(),
            points: g.polygonPoints!
                .map((p) => LatLng(p[0], p[1]))
                .toList(),
            color: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addCircleGeofence() async {
    if (_circleCenter == null) return;

    final nameController = TextEditingController();
    final radiusController = TextEditingController(text: _radius.toString());

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Geocerca Circular'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la geocerca',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: radiusController,
              decoration: const InputDecoration(
                labelText: 'Radio (metros)',
                border: OutlineInputBorder(),
                suffixText: 'm',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final radius = double.tryParse(radiusController.text) ?? _radius;
              if (name.isNotEmpty) {
                Navigator.pop(context, {'name': name, 'radius': radius});
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final g = Geofence(
          name: result['name'],
          type: 'circle',
          centerLat: _circleCenter!.latitude,
          centerLng: _circleCenter!.longitude,
          radius: result['radius'],
        );
        await GeofenceDao().insertGeofence(g);
        setState(() {
          _circleCenter = null;
          _isAddingCircle = false;
        });
        _loadGeofences();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Geocerca circular creada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear geocerca: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _addPolygonGeofence() async {
    if (_tempPolygonPoints.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se necesitan al menos 3 puntos para crear un polígono'),
        ),
      );
      return;
    }

    final nameController = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Geocerca Poligonal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la geocerca',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Puntos del polígono: ${_tempPolygonPoints.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context, name);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      try {
        final g = Geofence(
          name: name,
          type: 'polygon',
          polygonPoints: _tempPolygonPoints
              .map((p) => [p.latitude, p.longitude])
              .toList(),
        );
        await GeofenceDao().insertGeofence(g);
        setState(() {
          _tempPolygonPoints.clear();
          _isDrawingPolygon = false;
        });
        _loadGeofences();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Geocerca poligonal creada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear geocerca: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteGeofence(Geofence g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Estás seguro de que deseas eliminar la geocerca "${g.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await GeofenceDao().deleteGeofence(g.id!);
        _loadGeofences();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Geocerca eliminada exitosamente'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar geocerca: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _cancelCurrentAction() {
    setState(() {
      _isDrawingPolygon = false;
      _isAddingCircle = false;
      _circleCenter = null;
      _tempPolygonPoints.clear();
    });
  }

  void _onMapTap(LatLng position) {
    if (_isAddingCircle) {
      setState(() {
        _circleCenter = position;
      });
      _addCircleGeofence();
    } else if (_isDrawingPolygon) {
      setState(() {
        _tempPolygonPoints.add(position);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geocercas - Mapa Simple'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (_isDrawingPolygon || _isAddingCircle)
            IconButton(
              onPressed: _cancelCurrentAction,
              icon: const Icon(Icons.close),
              tooltip: 'Cancelar',
            )
          else ...[
            IconButton(
              onPressed: () {
                setState(() {
                  _isAddingCircle = true;
                  _isDrawingPolygon = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Toca en el mapa para crear una geocerca circular'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.circle_outlined),
              tooltip: 'Agregar círculo',
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _isDrawingPolygon = true;
                  _isAddingCircle = false;
                  _tempPolygonPoints.clear();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Toca en el mapa para agregar puntos del polígono'),
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              icon: const Icon(Icons.change_history), // Reemplazado Icons.polygon_outlined
              tooltip: 'Agregar polígono',
            ),
          ],
          if (_isDrawingPolygon && _tempPolygonPoints.length >= 3)
            IconButton(
              onPressed: _addPolygonGeofence,
              icon: const Icon(Icons.check),
              tooltip: 'Completar polígono',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Instrucciones de uso
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isAddingCircle
                              ? 'Toca en el mapa para crear un círculo'
                              : _isDrawingPolygon
                                  ? 'Toca para agregar puntos. Mínimo 3 puntos. (${_tempPolygonPoints.length} puntos)'
                                  : 'Usa los botones superiores para crear geocercas. Pellizca para zoom.',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                // Mapa personalizado
                Expanded(
                  flex: 2,
                  child: SimpleMapWidget(
                    onTap: _onMapTap,
                    circles: _circles,
                    polygons: _polygons,
                    tempPolygonPoints: _tempPolygonPoints,
                    circleCenter: _circleCenter,
                  ),
                ),
                // Lista de geocercas
                if (_geofences.isNotEmpty)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          const Text(
                            'Geocercas Creadas',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _geofences.length,
                              itemBuilder: (context, index) {
                                final geofence = _geofences[index];
                                return Card(
                                  child: ListTile(
                                    leading: Icon(
                                      geofence.type == 'circle'
                                          ? Icons.circle_outlined
                                          : Icons.change_history, // Reemplazado Icons.polygon_outlined
                                      color: geofence.type == 'circle'
                                          ? Colors.blue
                                          : Colors.red,
                                    ),
                                    title: Text(geofence.name),
                                    subtitle: Text(
                                      geofence.type == 'circle'
                                          ? 'Círculo - Radio: ${geofence.radius?.toInt()}m'
                                          : 'Polígono - ${geofence.polygonPoints?.length ?? 0} puntos',
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteGeofence(geofence),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}