import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fleet_provider.dart';
import '../models/vehicle.dart';

class VehicleListScreen extends StatelessWidget {
  const VehicleListScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Vehículos'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Consumer<FleetProvider>(
        builder: (context, fleetProvider, child) {
          final vehicles = fleetProvider.vehicles;
          
          if (vehicles.isEmpty) {
            return const Center(
              child: Text('No hay vehículos registrados'),
            );
          }

          return ListView.builder(
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: const Icon(Icons.directions_car, color: Colors.blue),
                  title: Text(
                    vehicle.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Color: ${vehicle.color}'),
                      Text('Año: ${vehicle.year}'),
                      if (vehicle.driver_code != null)
                        Text('Conductor: ${vehicle.driver_code}'),
                      Text('Estado: ${vehicle.isActive ? "Activo" : "Inactivo"}'),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleDetailScreen(vehicle: vehicle),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class VehicleDetailScreen extends StatelessWidget {
  final Vehicle vehicle; // Changed from Driver to Vehicle

  const VehicleDetailScreen({Key? key, required this.vehicle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Vehículo'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.directions_car),
                    title: const Text('Marca'),
                    subtitle: Text(vehicle.brand),
                  ),
                  ListTile(
                    leading: const Icon(Icons.car_rental),
                    title: const Text('Modelo'),
                    subtitle: Text(vehicle.model),
                  ),
                  ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Año'),
                    subtitle: Text(vehicle.year.toString()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Color'),
                    subtitle: Text(vehicle.color),
                  ),
                  ListTile(
                    leading: const Icon(Icons.confirmation_number),
                    title: const Text('Placa'),
                    subtitle: Text(vehicle.license_plate),
                  ),
                  if (vehicle.driver_code != null)
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('Código del Conductor'),
                      subtitle: Text(vehicle.driver_code!),
                    ),
                  ListTile(
                    leading: Icon(
                      vehicle.isActive ? Icons.check_circle : Icons.cancel,
                      color: vehicle.isActive ? Colors.green : Colors.red,
                    ),
                    title: const Text('Estado'),
                    subtitle: Text(vehicle.isActive ? 'Activo' : 'Inactivo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (vehicle.createdAt != null)
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.access_time),
                      title: const Text('Fecha de Registro'),
                      subtitle: Text(
                        '${vehicle.createdAt!.day}/${vehicle.createdAt!.month}/${vehicle.createdAt!.year}',
                      ),
                    ),
                    if (vehicle.updatedAt != null && 
                        vehicle.updatedAt != vehicle.createdAt)
                      ListTile(
                        leading: const Icon(Icons.update),
                        title: const Text('Última Actualización'),
                        subtitle: Text(
                          '${vehicle.updatedAt!.day}/${vehicle.updatedAt!.month}/${vehicle.updatedAt!.year}',
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}