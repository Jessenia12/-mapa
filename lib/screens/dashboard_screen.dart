import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fleet_provider.dart';
import '../screens/map_screen.dart';
import '../screens/geofence_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Cargar datos iniciales
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FleetProvider>(context, listen: false).loadFleet();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FleetProvider>(
      builder: (context, fleetProvider, child) {
        final drivers = fleetProvider.drivers;
        final isLoading = fleetProvider.isLoading;
        final error = fleetProvider.error;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Panel de Control'),
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.map),
                tooltip: 'Ver mapa en tiempo real',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.security),
                tooltip: 'Geocercas',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GeofenceScreen()),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Escanear QR',
                onPressed: () {
                  Navigator.pushNamed(context, '/qr_scanner');
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
                onPressed: () {
                  fleetProvider.refreshDrivers();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // Mostrar error si existe
              if (error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error, color: Colors.red.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          error,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => fleetProvider.clearError(),
                        iconSize: 20,
                      ),
                    ],
                  ),
                ),
              
              // Tarjetas de resumen
              _buildSummaryCards(fleetProvider),
              const SizedBox(height: 8),
              
              // Lista de conductores
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : drivers.isEmpty
                        ? _buildEmptyState()
                        : _buildDriversList(drivers, fleetProvider),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, '/driver_connection');
            },
            tooltip: 'Conectar conductor',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(FleetProvider fleetProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.directions_car,
              title: 'Total',
              value: fleetProvider.totalDrivers.toString(),
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.radio_button_checked,
              title: 'Activos',
              value: fleetProvider.activeDrivers.toString(),
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.route,
              title: 'En Ruta',
              value: fleetProvider.driversOnRoute.toString(),
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildSummaryCard(
              icon: Icons.wifi,
              title: 'Conectados',
              value: fleetProvider.connectedDrivers.toString(),
              color: Colors.purple,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No hay conductores conectados',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el botón + para conectar un conductor',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversList(List<Map<String, dynamic>> drivers, FleetProvider fleetProvider) {
    return RefreshIndicator(
      onRefresh: () async {
        await fleetProvider.refreshDrivers();
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: drivers.length,
        itemBuilder: (_, index) {
          final Map<String, dynamic> driver = drivers[index];
          final String driverCode = driver['driver_code'] as String? ?? driver['id'].toString();
          final String status = fleetProvider.getDriverStatus(driverCode);
          final dynamic location = fleetProvider.getDriverLocation(driverCode);
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            elevation: 2,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(status),
                child: Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(
                '${driver['name'] ?? 'Sin nombre'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.qr_code, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(driverCode),
                      const SizedBox(width: 16),
                      if (driver['license_number'] != null) ...[
                        Icon(Icons.credit_card, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text('${driver['license_number']}'),
                      ],
                    ],
                  ),
                  if (location != null && location['speed'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.speed,
                          size: 16,
                          color: (location['speed'] as double) > 60 ? Colors.red : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${(location['speed'] as double).toStringAsFixed(1)} km/h',
                          style: TextStyle(
                            color: (location['speed'] as double) > 60 ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (location != null && location['latitude'] != null && location['longitude'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${(location['latitude'] as double).toStringAsFixed(4)}, ${(location['longitude'] as double).toStringAsFixed(4)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: _getStatusColor(status),
                    size: 12,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getStatusText(status),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getStatusColor(status),
                    ),
                  ),
                ],
              ),
              onTap: () {
                _showDriverDetails(context, driver, fleetProvider);
              },
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'on_route':
        return Colors.orange;
      case 'inactive':
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.circle;
      case 'on_route':
        return Icons.navigation;
      case 'inactive':
      default:
        return Icons.circle_outlined;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Activo';
      case 'on_route':
        return 'En Ruta';
      case 'inactive':
      default:
        return 'Inactivo';
    }
  }

  void _showDriverDetails(BuildContext context, Map<String, dynamic> driver, FleetProvider fleetProvider) {
    final String driverCode = driver['driver_code'] as String? ?? driver['id'].toString();
    final String status = fleetProvider.getDriverStatus(driverCode);
    final dynamic location = fleetProvider.getDriverLocation(driverCode);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle del modal
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              Text(
                'Detalles del Conductor',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(driver['name'] ?? 'Sin nombre'),
                        subtitle: const Text('Nombre'),
                      ),
                      if (driver['email'] != null)
                        ListTile(
                          leading: const Icon(Icons.email),
                          title: Text(driver['email']),
                          subtitle: const Text('Email'),
                        ),
                      if (driver['phone'] != null)
                        ListTile(
                          leading: const Icon(Icons.phone),
                          title: Text(driver['phone']),
                          subtitle: const Text('Teléfono'),
                        ),
                      if (driver['license_number'] != null)
                        ListTile(
                          leading: const Icon(Icons.credit_card),
                          title: Text(driver['license_number']),
                          subtitle: const Text('Licencia'),
                        ),
                      ListTile(
                        leading: const Icon(Icons.qr_code),
                        title: Text(driverCode),
                        subtitle: const Text('Código'),
                      ),
                      ListTile(
                        leading: Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                        ),
                        title: Text(
                          _getStatusText(status),
                          style: TextStyle(color: _getStatusColor(status)),
                        ),
                        subtitle: const Text('Estado'),
                      ),
                      if (location != null && location['speed'] != null)
                        ListTile(
                          leading: Icon(
                            Icons.speed,
                            color: (location['speed'] as double) > 60 ? Colors.red : Colors.green,
                          ),
                          title: Text(
                            '${(location['speed'] as double).toStringAsFixed(1)} km/h',
                            style: TextStyle(
                              color: (location['speed'] as double) > 60 ? Colors.red : Colors.green,
                            ),
                          ),
                          subtitle: const Text('Velocidad actual'),
                        ),
                      if (location != null && location['latitude'] != null && location['longitude'] != null)
                        ListTile(
                          leading: const Icon(Icons.location_on),
                          title: Text(
                            '${(location['latitude'] as double).toStringAsFixed(4)}, ${(location['longitude'] as double).toStringAsFixed(4)}',
                          ),
                          subtitle: const Text('Última ubicación'),
                        ),
                      if (location != null && location['timestamp'] != null)
                        ListTile(
                          leading: const Icon(Icons.access_time),
                          title: Text(
                            _formatTimestamp(location['timestamp']),
                          ),
                          subtitle: const Text('Última actualización'),
                        ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapScreen(focusDriverCode: driverCode),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Ver en Mapa'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/driver_detail',
                          arguments: driver,
                        );
                      },
                      icon: const Icon(Icons.info),
                      label: const Text('Más detalles'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final DateTime dateTime = DateTime.parse(timestamp);
      final Duration difference = DateTime.now().difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Hace menos de 1 minuto';
      } else if (difference.inMinutes < 60) {
        return 'Hace ${difference.inMinutes} minutos';
      } else if (difference.inHours < 24) {
        return 'Hace ${difference.inHours} horas';
      } else {
        return 'Hace ${difference.inDays} días';
      }
    } catch (e) {
      return timestamp;
    }
  }
}