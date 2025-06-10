import 'dart:convert';

class Geofence {
  int? id;
  String name;
  String type; // 'circle' o 'polygon'
  double? centerLat;
  double? centerLng;
  double? radius; // en metros
  List<List<double>>? polygonPoints; // [[lat1, lng1], [lat2, lng2], ...]

  Geofence({
    this.id,
    required this.name,
    required this.type,
    this.centerLat,
    this.centerLng,
    this.radius,
    this.polygonPoints,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'centerLat': centerLat,
      'centerLng': centerLng,
      'radius': radius,
      'polygonPoints': polygonPoints != null ? jsonEncode(polygonPoints) : null,
    };
  }

  factory Geofence.fromMap(Map<String, dynamic> map) {
    return Geofence(
      id: map['id'],
      name: map['name'],
      type: map['type'],
      centerLat: map['centerLat'],
      centerLng: map['centerLng'],
      radius: map['radius'],
      polygonPoints: map['polygonPoints'] != null
          ? List<List<double>>.from(jsonDecode(map['polygonPoints'])
              .map((point) => List<double>.from(point)))
          : null,
    );
  }
}
