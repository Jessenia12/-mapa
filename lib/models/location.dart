class Location {
  int? id;
  double latitude;
  double longitude;
  DateTime timestamp;
  double speed;
  String? driverCode;

  Location({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.speed,
    this.driverCode,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'speed': speed,
      'driverCode': driverCode,
    };
  }

  factory Location.fromMap(Map<String, dynamic> map) {
    return Location(
      id: map['id'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      timestamp: DateTime.parse(map['timestamp']),
      speed: map['speed'],
      driverCode: map['driverCode'],
    );
  }
}
