import 'package:uuid/uuid.dart';

class Driver {
  int? id;
  String name;
  String idNumber;
  String plateNumber;
  String code; // Código único generado
  bool isActive;
  DateTime? lastConnection;
  String? currentStatus; // 'active', 'inactive', 'on_route'
  double? lastLatitude;   // Coordenadas
  double? lastLongitude;  // Coordenadas
  double? lastSpeed;      // Velocidad
  String? email;          // Email del conductor
  String? phone;          // Teléfono del conductor
  String? licenseNumber;  // Número de licencia
  DateTime? createdAt;    // Fecha de creación
  DateTime? updatedAt;    // Fecha de actualización

  Driver({
    this.id,
    required this.name,
    required this.idNumber,
    required this.plateNumber,
    String? code,
    this.isActive = true,
    this.lastConnection,
    this.currentStatus = 'inactive',
    this.lastLatitude,
    this.lastLongitude,
    this.lastSpeed,
    this.email,
    this.phone,
    this.licenseNumber,
    this.createdAt,
    this.updatedAt,
  }) : code = code ?? const Uuid().v4();

  // Método copyWith completo
  Driver copyWith({
    int? id,
    String? name,
    String? idNumber,
    String? plateNumber,
    String? code,
    bool? isActive,
    DateTime? lastConnection,
    String? currentStatus,
    double? lastLatitude,
    double? lastLongitude,
    double? lastSpeed,
    String? email,
    String? phone,
    String? licenseNumber,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Driver(
      id: id ?? this.id,
      name: name ?? this.name,
      idNumber: idNumber ?? this.idNumber,
      plateNumber: plateNumber ?? this.plateNumber,
      code: code ?? this.code,
      isActive: isActive ?? this.isActive,
      lastConnection: lastConnection ?? this.lastConnection,
      currentStatus: currentStatus ?? this.currentStatus,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastSpeed: lastSpeed ?? this.lastSpeed,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Convertir a Map para la base de datos (compatible con DAO)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'idNumber': idNumber,
      'plateNumber': plateNumber,
      'code': code,
      'driver_code': code, // Mantener compatibilidad con DAO
      'isActive': isActive ? 1 : 0,
      'lastConnection': lastConnection?.toIso8601String(),
      'currentStatus': currentStatus,
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'lastSpeed': lastSpeed,
      'email': email,
      'phone': phone,
      'license_number': licenseNumber, // Campo compatible con DAO
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Crear Driver desde Map de la base de datos (compatible con DAO)
  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'],
      name: map['name'] ?? '',
      idNumber: map['idNumber'] ?? map['license_number'] ?? 'N/A',
      plateNumber: map['plateNumber'] ?? 'N/A',
      code: map['code'] ?? map['driver_code'] ?? '',
      isActive: (map['isActive'] ?? 1) == 1,
      lastConnection: map['lastConnection'] != null 
          ? DateTime.parse(map['lastConnection'])
          : null,
      currentStatus: map['currentStatus'] ?? 'inactive',
      lastLatitude: map['lastLatitude']?.toDouble(),
      lastLongitude: map['lastLongitude']?.toDouble(),
      lastSpeed: map['lastSpeed']?.toDouble(),
      email: map['email'],
      phone: map['phone'],
      licenseNumber: map['license_number'],
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'])
          : null,
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'])
          : null,
    );
  }

  // Generar código QR
  String generateQRCode() {
    return 'DRIVER:$code';
  }

  // Verificar si está conectado (último ping hace menos de 5 minutos)
  bool get isConnected {
    if (lastConnection == null) return false;
    return DateTime.now().difference(lastConnection!).inMinutes < 5;
  }

  // Actualizar ubicación del conductor
  void updateLocation(double latitude, double longitude, double speed) {
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastSpeed = speed;
    lastConnection = DateTime.now();
    currentStatus = 'active';
    updatedAt = DateTime.now();
  }

  // Marcar como activo/inactivo
  void setActive(bool active) {
    isActive = active;
    currentStatus = active ? 'active' : 'inactive';
    if (active) {
      lastConnection = DateTime.now();
    }
    updatedAt = DateTime.now();
  }

  // Obtener información de estado formateada
  String get statusText {
    switch (currentStatus) {
      case 'active':
        return 'Activo';
      case 'on_route':
        return 'En ruta';
      case 'inactive':
        return 'Inactivo';
      default:
        return 'Desconocido';
    }
  }

  // Obtener color del estado
  String get statusColor {
    switch (currentStatus) {
      case 'active':
        return '#4CAF50'; // verde
      case 'on_route':
        return '#FF9800'; // naranja
      case 'inactive':
        return '#9E9E9E'; // gris
      default:
        return '#757575'; // gris oscuro
    }
  }

  @override
  String toString() {
    return 'Driver(id: $id, name: $name, code: $code, isActive: $isActive, status: $currentStatus)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Driver &&
        other.id == id &&
        other.code == code;
  }

  @override
  int get hashCode => id.hashCode ^ code.hashCode;
}