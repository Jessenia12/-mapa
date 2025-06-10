import 'dart:convert';

class Route {
  int? id;
  String name;
  String description;
  String driverCode;
  List<RoutePoint> waypoints;
  String status; // 'assigned', 'in_progress', 'completed', 'cancelled'
  DateTime? assignedAt;
  DateTime? startedAt;
  DateTime? completedAt;
  double? estimatedDistance; // en kilómetros
  int? estimatedDuration; // en minutos

  Route({
    this.id,
    required this.name,
    required this.description,
    required this.driverCode,
    required this.waypoints,
    this.status = 'assigned',
    this.assignedAt,
    this.startedAt,
    this.completedAt,
    this.estimatedDistance,
    this.estimatedDuration,
  }) {
    assignedAt ??= DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'driverCode': driverCode,
      'waypoints': jsonEncode(waypoints.map((point) => point.toMap()).toList()),
      'status': status,
      'assignedAt': assignedAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'estimatedDistance': estimatedDistance,
      'estimatedDuration': estimatedDuration,
    };
  }

  factory Route.fromMap(Map<String, dynamic> map) {
    List<RoutePoint> waypoints = [];
    if (map['waypoints'] != null) {
      try {
        final waypointsJson = jsonDecode(map['waypoints']) as List;
        waypoints = waypointsJson.map((point) => RoutePoint.fromMap(point as Map<String, dynamic>)).toList();
      } catch (e) {
        print('Error parsing waypoints: $e');
        waypoints = [];
      }
    }

    return Route(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      driverCode: map['driverCode'] as String? ?? '',
      waypoints: waypoints,
      status: map['status'] as String? ?? 'assigned',
      assignedAt: map['assignedAt'] != null 
          ? DateTime.tryParse(map['assignedAt'] as String)
          : null,
      startedAt: map['startedAt'] != null 
          ? DateTime.tryParse(map['startedAt'] as String)
          : null,
      completedAt: map['completedAt'] != null 
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
      estimatedDistance: (map['estimatedDistance'] as num?)?.toDouble(),
      estimatedDuration: map['estimatedDuration'] as int?,
    );
  }

  // Método copyWith para inmutabilidad
  Route copyWith({
    int? id,
    String? name,
    String? description,
    String? driverCode,
    List<RoutePoint>? waypoints,
    String? status,
    DateTime? assignedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    double? estimatedDistance,
    int? estimatedDuration,
  }) {
    return Route(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      driverCode: driverCode ?? this.driverCode,
      waypoints: waypoints ?? List.from(this.waypoints),
      status: status ?? this.status,
      assignedAt: assignedAt ?? this.assignedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
    );
  }

  bool get isCompleted => status == 'completed';
  bool get isInProgress => status == 'in_progress';
  bool get isAssigned => status == 'assigned';
  bool get isCancelled => status == 'cancelled';

  double get completionPercentage {
    if (waypoints.isEmpty) return 0.0;
    int completedWaypoints = waypoints.where((w) => w.isCompleted).length;
    return (completedWaypoints / waypoints.length) * 100;
  }

  // Método para obtener el siguiente punto no completado
  RoutePoint? get nextWaypoint {
    try {
      return waypoints.firstWhere((w) => !w.isCompleted);
    } catch (e) {
      return null; // Todos los puntos están completados
    }
  }

  // Validar que la ruta esté bien formada
  bool get isValid {
    return name.isNotEmpty && 
           driverCode.isNotEmpty && 
           waypoints.isNotEmpty &&
           ['assigned', 'in_progress', 'completed', 'cancelled'].contains(status);
  }

  @override
  String toString() {
    return 'Route{id: $id, name: $name, status: $status, waypoints: ${waypoints.length}}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Route && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class RoutePoint {
  int? id;
  String name;
  String? description;
  double latitude;
  double longitude;
  int order; // Orden en la ruta
  bool isCompleted;
  DateTime? completedAt;
  String type; // 'pickup', 'delivery', 'checkpoint', 'destination'

  RoutePoint({
    this.id,
    required this.name,
    this.description,
    required this.latitude,
    required this.longitude,
    required this.order,
    this.isCompleted = false,
    this.completedAt,
    this.type = 'checkpoint',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'order': order,
      'isCompleted': isCompleted ? 1 : 0, // SQLite compatibility
      'completedAt': completedAt?.toIso8601String(),
      'type': type,
    };
  }

  factory RoutePoint.fromMap(Map<String, dynamic> map) {
    return RoutePoint(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      description: map['description'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      order: map['order'] as int? ?? 0,
      isCompleted: map['isCompleted'] == 1 || map['isCompleted'] == true,
      completedAt: map['completedAt'] != null 
          ? DateTime.tryParse(map['completedAt'] as String)
          : null,
      type: map['type'] as String? ?? 'checkpoint',
    );
  }

  // Método copyWith
  RoutePoint copyWith({
    int? id,
    String? name,
    String? description,
    double? latitude,
    double? longitude,
    int? order,
    bool? isCompleted,
    DateTime? completedAt,
    String? type,
  }) {
    return RoutePoint(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      order: order ?? this.order,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      type: type ?? this.type,
    );
  }

  String get typeIcon {
    switch (type) {
      case 'pickup':
        return '📦';
      case 'delivery':
        return '🚚';
      case 'destination':
        return '🏁';
      case 'checkpoint':
      default:
        return '📍';
    }
  }

  String get typeDisplayName {
    switch (type) {
      case 'pickup':
        return 'Recogida';
      case 'delivery':
        return 'Entrega';
      case 'destination':
        return 'Destino';
      case 'checkpoint':
      default:
        return 'Punto de control';
    }
  }

  // Validar que el punto sea válido
  bool get isValid {
    return name.isNotEmpty && 
           latitude >= -90 && latitude <= 90 &&
           longitude >= -180 && longitude <= 180 &&
           order >= 0 &&
           ['pickup', 'delivery', 'checkpoint', 'destination'].contains(type);
  }

  // Marcar como completado
  void markAsCompleted() {
    isCompleted = true;
    completedAt = DateTime.now();
  }

  @override
  String toString() {
    return 'RoutePoint{id: $id, name: $name, type: $type, order: $order, completed: $isCompleted}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RoutePoint && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}