class Vehicle {
  int? id;
  String license_plate;
  String model;
  String brand;
  int year;
  String color;
  String? driver_code;
  bool isActive;
  DateTime? createdAt;
  DateTime? updatedAt;
  double? maxSpeed; // AGREGADO: Campo para límite de velocidad

  Vehicle({
    this.id,
    required this.license_plate,
    required this.model,
    required this.brand,
    required this.year,
    required this.color,
    this.driver_code,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.maxSpeed, // AGREGADO: Parámetro para velocidad máxima
  }) {
    createdAt ??= DateTime.now();
    updatedAt ??= DateTime.now();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'license_plate': license_plate,
      'model': model,
      'brand': brand,
      'year': year,
      'color': color,
      'driver_code': driver_code,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'max_speed': maxSpeed, // AGREGADO: Mapeo de velocidad máxima
    };
  }

  factory Vehicle.fromMap(Map<String, dynamic> map) {
    return Vehicle(
      id: map['id'],
      license_plate: map['license_plate'] ?? '',
      model: map['model'] ?? '',
      brand: map['brand'] ?? '',
      year: map['year'] ?? DateTime.now().year,
      color: map['color'] ?? '',
      driver_code: map['driver_code'],
      isActive: (map['isActive'] ?? 1) == 1,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'])
          : DateTime.now(),
      maxSpeed: map['max_speed']?.toDouble(), // AGREGADO: Parsing de velocidad máxima
    );
  }

  String get displayName => '$brand $model ($license_plate)';

  // AGREGADO: Getter para mostrar velocidad máxima formateada
  String get speedLimitDisplay => maxSpeed != null 
      ? '${maxSpeed!.toStringAsFixed(0)} km/h' 
      : 'Sin límite';

  // AGREGADO: Método para verificar si tiene límite de velocidad
  bool get hasSpeedLimit => maxSpeed != null && maxSpeed! > 0;

  // AGREGADO: Método copyWith para actualizaciones
  Vehicle copyWith({
    int? id,
    String? license_plate,
    String? model,
    String? brand,
    int? year,
    String? color,
    String? driver_code,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? maxSpeed,
  }) {
    return Vehicle(
      id: id ?? this.id,
      license_plate: license_plate ?? this.license_plate,
      model: model ?? this.model,
      brand: brand ?? this.brand,
      year: year ?? this.year,
      color: color ?? this.color,
      driver_code: driver_code ?? this.driver_code,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      maxSpeed: maxSpeed ?? this.maxSpeed,
    );
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, license_plate: $license_plate, brand: $brand, model: $model, maxSpeed: $maxSpeed)';
  }
}