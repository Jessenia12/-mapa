import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/driver.dart';

class DriverMarker {
  static Marker createDriverMarker(Driver driver, {VoidCallback? onTap}) {
    // Verificar si tiene coordenadas válidas
    if (driver.lastLatitude == null || driver.lastLongitude == null) {
      return Marker(
        point: LatLng(0, 0),
        child: SizedBox.shrink(),
      );
    }

    return Marker(
      point: LatLng(driver.lastLatitude!, driver.lastLongitude!),
      width: 50,
      height: 50,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Círculo de fondo con color según estado
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getDriverColor(driver),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _getDriverIcon(driver),
                color: Colors.white,
                size: 20,
              ),
            ),
            // Indicador de velocidad si está disponible
            if (driver.lastSpeed != null && driver.lastSpeed! > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getSpeedColor(driver.lastSpeed!),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '${driver.lastSpeed!.toInt()}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            // Indicador de conexión
            if (!driver.isConnected)
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Icon(
                    Icons.wifi_off,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Color _getDriverColor(Driver driver) {
    if (!driver.isActive) {
      return Colors.red;
    }
    
    if (!driver.isConnected) {
      return Colors.grey;
    }
    
    // Determinar color basado en velocidad
    if (driver.lastSpeed != null) {
      if (driver.lastSpeed! > 80) {
        return Colors.red;
      } else if (driver.lastSpeed! > 40) {
        return Colors.orange;
      } else if (driver.lastSpeed! > 0) {
        return Colors.green;
      }
    }
    
    // Color basado en estado
    switch (driver.currentStatus) {
      case 'active':
        return Colors.blue;
      case 'on_route':
        return Colors.purple;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  static Color _getSpeedColor(double speed) {
    if (speed > 80) return Colors.red;
    if (speed > 60) return Colors.orange;
    if (speed > 40) return Colors.yellow.shade700;
    return Colors.green;
  }

  static IconData _getDriverIcon(Driver driver) {
    if (!driver.isActive) {
      return Icons.person_off;
    }
    
    switch (driver.currentStatus) {
      case 'on_route':
        return Icons.directions_car;
      case 'inactive':
        return Icons.pause;
      default:
        return Icons.person;
    }
  }

  static String getDriverInfo(Driver driver) {
    List<String> info = [];
    
    info.add('${driver.name} - ${driver.plateNumber}');
    
    if (driver.lastSpeed != null) {
      info.add('${driver.lastSpeed!.toStringAsFixed(0)} km/h');
    }
    
    if (driver.lastConnection != null) {
      info.add(_timeAgo(driver.lastConnection!));
    }
    
    if (driver.currentStatus != null) {
      String statusText = '';
      switch (driver.currentStatus) {
        case 'active':
          statusText = 'Activo';
          break;
        case 'inactive':  
          statusText = 'Inactivo';
          break;
        case 'on_route':
          statusText = 'En ruta';
          break;
        default:
          statusText = driver.currentStatus!;
      }
      info.add('Estado: $statusText');
    }
    
    return info.join(' • ');
  }

  // Helper method para calcular tiempo transcurrido
  static String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return 'hace ${difference.inDays} día${difference.inDays == 1 ? '' : 's'}';
    } else if (difference.inHours > 0) {
      return 'hace ${difference.inHours} hora${difference.inHours == 1 ? '' : 's'}';
    } else if (difference.inMinutes > 0) {
      return 'hace ${difference.inMinutes} minuto${difference.inMinutes == 1 ? '' : 's'}';
    } else {
      return 'hace un momento';
    }
  }

  // Crear múltiples marcadores para una lista de conductores
  static List<Marker> createDriverMarkers(
    List<Driver> drivers, {
    Function(Driver)? onDriverTap,
  }) {
    return drivers
        .where((driver) => 
            driver.lastLatitude != null && 
            driver.lastLongitude != null)
        .map((driver) => createDriverMarker(
              driver,
              onTap: onDriverTap != null ? () => onDriverTap(driver) : null,
            ))
        .toList();
  }

  // Crear marcador con animación de pulsación para conductores activos
  static Marker createAnimatedDriverMarker(Driver driver, {VoidCallback? onTap}) {
    if (driver.lastLatitude == null || driver.lastLongitude == null) {
      return Marker(
        point: LatLng(0, 0),
        child: SizedBox.shrink(),
      );
    }

    return Marker(
      point: LatLng(driver.lastLatitude!, driver.lastLongitude!),
      width: 60,
      height: 60,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animación de pulso para conductores en movimiento
            if (driver.lastSpeed != null && driver.lastSpeed! > 0)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(seconds: 2),
                builder: (context, value, child) {
                  return Container(
                    width: 60 * value,
                    height: 60 * value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getDriverColor(driver).withOpacity(0.3 * (1 - value)),
                    ),
                  );
                },
              ),
            // Marcador principal
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getDriverColor(driver),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _getDriverIcon(driver),
                color: Colors.white,
                size: 20,
              ),
            ),
            // Indicadores adicionales
            if (driver.lastSpeed != null && driver.lastSpeed! > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getSpeedColor(driver.lastSpeed!),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Text(
                    '${driver.lastSpeed!.toInt()}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (!driver.isConnected)
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Icon(
                    Icons.wifi_off,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Widget personalizado para mostrar información detallada del conductor
class DriverInfoWidget extends StatelessWidget {
  final Driver driver;
  final VoidCallback? onClose;
  final VoidCallback? onViewDetails;
  final VoidCallback? onAssignRoute;
  final VoidCallback? onTrackLocation;

  const DriverInfoWidget({
    Key? key,
    required this.driver,
    this.onClose,
    this.onViewDetails,
    this.onAssignRoute,
    this.onTrackLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      backgroundColor: _getStatusColor(),
                      radius: 25,
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    if (!driver.isConnected)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(
                            Icons.wifi_off,
                            color: Colors.white,
                            size: 10,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        driver.plateNumber,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        margin: EdgeInsets.only(top: 4),
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getStatusText(driver.currentStatus ?? 'unknown'),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: onClose,
                  ),
              ],
            ),
            SizedBox(height: 16),
            _buildInfoRow(Icons.badge, 'Cédula', driver.idNumber),
            _buildInfoRow(Icons.qr_code, 'Código', driver.code),
            if (driver.lastSpeed != null)
              _buildInfoRow(
                Icons.speed,
                'Velocidad',
                '${driver.lastSpeed!.toStringAsFixed(0)} km/h',
                valueColor: DriverMarker._getSpeedColor(driver.lastSpeed!),
              ),
            if (driver.lastConnection != null)
              _buildInfoRow(
                Icons.access_time,
                'Última conexión',
                DriverMarker._timeAgo(driver.lastConnection!),
              ),
            _buildInfoRow(
              Icons.wifi,
              'Conexión',
              driver.isConnected ? 'Conectado' : 'Desconectado',
              valueColor: driver.isConnected ? Colors.green : Colors.red,
            ),
            _buildInfoRow(
              Icons.toggle_on,
              'Activo',
              driver.isActive ? 'Sí' : 'No',
              valueColor: driver.isActive ? Colors.green : Colors.red,
            ),
            if (driver.lastLatitude != null && driver.lastLongitude != null)
              _buildInfoRow(
                Icons.location_on,
                'Coordenadas',
                '${driver.lastLatitude!.toStringAsFixed(6)}, ${driver.lastLongitude!.toStringAsFixed(6)}',
              ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onViewDetails != null)
                  ElevatedButton.icon(
                    onPressed: onViewDetails,
                    icon: Icon(Icons.info, size: 16),
                    label: Text('Detalles'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (onAssignRoute != null)
                  ElevatedButton.icon(
                    onPressed: onAssignRoute,
                    icon: Icon(Icons.route, size: 16),
                    label: Text('Asignar Ruta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (onTrackLocation != null)
                  ElevatedButton.icon(
                    onPressed: onTrackLocation,
                    icon: Icon(Icons.my_location, size: 16),
                    label: Text('Seguir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    if (!driver.isActive) return Colors.red;
    if (!driver.isConnected) return Colors.grey;
    
    if (driver.lastSpeed != null) {
      if (driver.lastSpeed! > 80) return Colors.red;
      if (driver.lastSpeed! > 40) return Colors.orange;
      if (driver.lastSpeed! > 0) return Colors.green;
    }
    
    switch (driver.currentStatus) {
      case 'active':
        return Colors.blue;
      case 'on_route':
        return Colors.purple;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Activo';
      case 'inactive':
        return 'Inactivo';
      case 'on_route':
        return 'En ruta';
      default:
        return status.isEmpty ? 'Desconocido' : status;
    }
  }
}