import 'dart:math' as math;
import '../models/location.dart';

// Enums que necesitas (si no los tienes en otro archivo)
enum GeofenceType {
  restricted,
  safe,
  checkpoint,
  polygonal,
  circular,
}

enum AlertType {
  geofenceEntry,
  geofenceExit,
  speedLimit,
  routeDeviation,
  inactivity,
}

class GeofenceAlert {
  final int? id;
  final int driverId;
  final int geofenceId;
  final AlertType alertType;
  final String message;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  const GeofenceAlert({
    this.id,
    required this.driverId,
    required this.geofenceId,
    required this.alertType,
    required this.message,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });
}

class Geofence {
  final int? id;
  final String name;
  final String description;
  final double? centerLatitude;
  final double? centerLongitude;
  final double? radius;
  final List<Location>? polygon;
  final GeofenceType type;
  final bool isActive;
  final List<int> vehicleIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool alertOnEntry;
  final bool alertOnExit;
  final String? alertMessage;
  final List<String> notificationEmails;

  const Geofence({
    this.id,
    required this.name,
    required this.description,
    this.centerLatitude,
    this.centerLongitude,
    this.radius,
    this.polygon,
    required this.type,
    this.isActive = true,
    this.vehicleIds = const [],
    required this.createdAt,
    required this.updatedAt,
    this.alertOnEntry = true,
    this.alertOnExit = false,
    this.alertMessage,
    this.notificationEmails = const [],
  });

  bool containsPoint(double latitude, double longitude) {
    if (type == GeofenceType.circular && centerLatitude != null && centerLongitude != null && radius != null) {
      return _isPointInCircle(latitude, longitude, centerLatitude!, centerLongitude!, radius!);
    } else if (type == GeofenceType.polygonal && polygon != null && polygon!.isNotEmpty) {
      return _isPointInPolygon(latitude, longitude, polygon!);
    }
    return false;
  }

  bool _isPointInCircle(double lat, double lng, double centerLat, double centerLng, double radiusInMeters) {
    double distance = LocationUtils.calculateDistance(lat, lng, centerLat, centerLng);
    return distance <= radiusInMeters;
  }

  bool _isPointInPolygon(double lat, double lng, List<Location> polygon) {
    int intersectCount = 0;
    for (int j = polygon.length - 1, i = 0; i < polygon.length; j = i++) {
      if (((polygon[i].latitude <= lat && lat < polygon[j].latitude) ||
           (polygon[j].latitude <= lat && lat < polygon[i].latitude)) &&
          (lng < (polygon[j].longitude - polygon[i].longitude) * (lat - polygon[i].latitude) / 
           (polygon[j].latitude - polygon[i].latitude) + polygon[i].longitude)) {
        intersectCount++;
      }
    }
    return (intersectCount & 1) == 1;
  }
}

class LocationUtils {
  /// Calcula la distancia entre dos puntos en metros usando la fórmula de Haversine
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Radio de la Tierra en metros
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Calcula la distancia de un punto a un segmento de línea
  static double distanceToLineSegment(double px, double py, double x1, double y1, double x2, double y2) {
    double dx = x2 - x1;
    double dy = y2 - y1;
    
    if (dx != 0 || dy != 0) {
      double t = ((px - x1) * dx + (py - y1) * dy) / (dx * dx + dy * dy);
      
      if (t > 1) {
        dx = px - x2;
        dy = py - y2;
      } else if (t > 0) {
        dx = px - (x1 + dx * t);
        dy = py - (y1 + dy * t);
      } else {
        dx = px - x1;
        dy = py - y1;
      }
    } else {
      dx = px - x1;
      dy = py - y1;
    }
    
    // Convertir a metros usando aproximación
    return math.sqrt(dx * dx + dy * dy) * 111000; // Aproximadamente 111km por grado
  }

  /// Convierte grados a radianes
  static double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Calcula el bearing (dirección) entre dos puntos
  static double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    double dLon = _toRadians(lon2 - lon1);
    double lat1Rad = _toRadians(lat1);
    double lat2Rad = _toRadians(lat2);
    
    double y = math.sin(dLon) * math.cos(lat2Rad);
    double x = math.cos(lat1Rad) * math.sin(lat2Rad) - 
               math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);
    
    double bearing = math.atan2(y, x);
    return (bearing * 180 / math.pi + 360) % 360;
  }

  /// Determina si un conductor debe recibir una alerta basada en su ubicación y las geocercas
  static List<GeofenceAlert> checkGeofenceAlerts(
    int driverId,
    double currentLat,
    double currentLng,
    List<Geofence> geofences,
    Map<int, bool> previousStates, // Estado anterior: true = dentro, false = fuera
  ) {
    List<GeofenceAlert> alerts = [];
    DateTime now = DateTime.now();

    for (Geofence geofence in geofences) {
      if (!geofence.isActive) continue;

      bool isInside = geofence.containsPoint(currentLat, currentLng);
      bool wasInside = previousStates[geofence.id] ?? false;

      // Detectar entrada a geocerca
      if (isInside && !wasInside && geofence.alertOnEntry) {
        String message = geofence.alertMessage ?? 
                        _getDefaultAlertMessage(geofence.type, AlertType.geofenceEntry, geofence.name);
        
        alerts.add(GeofenceAlert(
          driverId: driverId,
          geofenceId: geofence.id!,
          alertType: AlertType.geofenceEntry,
          message: message,
          latitude: currentLat,
          longitude: currentLng,
          timestamp: now,
          metadata: {
            'geofence_name': geofence.name,
            'geofence_type': geofence.type.name,
          },
        ));
      }

      // Detectar salida de geocerca
      if (!isInside && wasInside && geofence.alertOnExit) {
        String message = geofence.alertMessage ?? 
                        _getDefaultAlertMessage(geofence.type, AlertType.geofenceExit, geofence.name);
        
        alerts.add(GeofenceAlert(
          driverId: driverId,
          geofenceId: geofence.id!,
          alertType: AlertType.geofenceExit,
          message: message,
          latitude: currentLat,
          longitude: currentLng,
          timestamp: now,
          metadata: {
            'geofence_name': geofence.name,
            'geofence_type': geofence.type.name,
          },
        ));
      }

      // Actualizar estado
      previousStates[geofence.id!] = isInside;
    }

    return alerts;
  }

  static String _getDefaultAlertMessage(GeofenceType geofenceType, AlertType alertType, String geofenceName) {
    switch (geofenceType) {
      case GeofenceType.restricted:
        return alertType == AlertType.geofenceEntry 
            ? '⚠️ ALERTA: Conductor ingresó a zona restringida "$geofenceName"'
            : '✅ Conductor salió de zona restringida "$geofenceName"';
      case GeofenceType.safe:
        return alertType == AlertType.geofenceEntry 
            ? '✅ Conductor ingresó a zona segura "$geofenceName"'
            : '⚠️ ALERTA: Conductor salió de zona segura "$geofenceName"';
      case GeofenceType.checkpoint:
        return alertType == AlertType.geofenceEntry 
            ? '📍 Conductor llegó al checkpoint "$geofenceName"'
            : '📍 Conductor salió del checkpoint "$geofenceName"';
      default:
        return alertType == AlertType.geofenceEntry 
            ? '📍 Conductor ingresó a "$geofenceName"'
            : '📍 Conductor salió de "$geofenceName"';
    }
  }
}