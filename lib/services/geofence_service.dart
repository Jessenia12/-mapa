import 'dart:math';
import '../models/geofence.dart';

class GeofenceService {
  static bool isInsideGeofence(
    double lat,
    double lng,
    Geofence geofence,
  ) {
    if (geofence.type == 'circle') {
      return _isInsideCircle(lat, lng, geofence);
    } else if (geofence.type == 'polygon') {
      return _isInsidePolygon(lat, lng, geofence);
    }
    return false;
  }

  static bool _isInsideCircle(double lat, double lng, Geofence g) {
    final distance = _calculateDistance(lat, lng, g.centerLat!, g.centerLng!);
    return distance <= (g.radius ?? 0);
  }

  static double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // metros
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);

  static bool _isInsidePolygon(double lat, double lng, Geofence g) {
    if (g.polygonPoints == null) return false;

    bool inside = false;
    final points = g.polygonPoints!;
    for (int i = 0, j = points.length - 1; i < points.length; j = i++) {
      final xi = points[i][0], yi = points[i][1];
      final xj = points[j][0], yj = points[j][1];

      final intersect = ((yi > lng) != (yj > lng)) &&
          (lat < (xj - xi) * (lng - yi) / (yj - yi + 1e-9) + xi);

      if (intersect) inside = !inside;
    }
    return inside;
  }
}
