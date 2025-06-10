import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/fleet_provider.dart';
import 'providers/geofence_provider.dart';
import 'providers/gps_provider.dart'; // Asegúrate de que exporta GPSProvider

import 'screens/dashboard_screen.dart';
import 'screens/map_screen.dart';
import 'screens/vehicle_list_screen.dart';
import 'screens/geofence_screen.dart';
import 'screens/driver_connect_screen.dart';
import 'screens/qr_scanner_screen.dart';

import 'models/vehicle.dart';
import 'models/driver.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FleetProvider()),
        ChangeNotifierProvider(create: (_) => GeofenceProvider()),
        ChangeNotifierProvider(create: (_) => GPSProvider()), // CORREGIDO: Clase con nombre correcto
      ],
      child: MaterialApp(
        title: 'Monitoreo GPS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.blue.shade800,
            foregroundColor: Colors.white,
          ),
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const DashboardScreen(),
          '/map': (context) => const MapScreen(),
          '/vehicles': (context) => const VehicleListScreen(),
          '/geofences': (context) => const GeofenceScreen(),
          '/driver_connection': (context) => const DriverConnectScreen(),
          '/qr_scanner': (context) => const QRScannerScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/vehicle_detail':
              final vehicle = settings.arguments as Vehicle?;
              return MaterialPageRoute(
                builder: (context) => VehicleDetailScreen(vehicle: vehicle),
              );
            case '/driver_detail':
              final driver = settings.arguments as Driver?;
              return MaterialPageRoute(
                builder: (context) => DriverDetailScreen(driver: driver),
              );
            case '/map_focused':
              final args = settings.arguments as Map<String, dynamic>?;
              return MaterialPageRoute(
                builder: (context) => MapScreen(
                  focusDriver: args?['driver'],
                  // Si tienes un vehículo, podrías convertirlo a driver o manejarlo de otra forma
                  // focusDriver: args?['vehicle'] != null ? _vehicleToDriver(args['vehicle']) : args?['driver'],
                ),
              );
            default:
              return null;
          }
        },
      ),
    );
  }
}

// -------- Pantalla Detalle Vehículo --------
class VehicleDetailScreen extends StatelessWidget {
  final Vehicle? vehicle;

  const VehicleDetailScreen({super.key, this.vehicle});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Vehículo')),
      body: vehicle == null
          ? const Center(child: Text('No se encontró información del vehículo'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Información del Vehículo', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.directions_car),
                            title: Text(vehicle!.license_plate), // ← CORREGIDO
                            subtitle: const Text('Placa'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.settings),
                            title: Text(vehicle!.model),
                            subtitle: const Text('Modelo'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.calendar_today),
                            title: Text(vehicle!.year.toString()),
                            subtitle: const Text('Año'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // OPCIÓN 1: Ir al mapa general (sin foco específico)
                        Navigator.pushNamed(context, '/map');
                        
                        // OPCIÓN 2: Si quieres buscar el conductor asociado al vehículo
                        // Necesitarías implementar una función para encontrar el conductor por placa
                        // Navigator.pushNamed(
                        //   context,
                        //   '/map_focused',
                        //   arguments: {'vehicle': vehicle},
                        // );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Ver en Mapa'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// -------- Pantalla Detalle Conductor --------
class DriverDetailScreen extends StatelessWidget {
  final Driver? driver;

  const DriverDetailScreen({super.key, this.driver});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del Conductor')),
      body: driver == null
          ? const Center(child: Text('No se encontró información del conductor'))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Información del Conductor', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 16),
                          ListTile(
                            leading: const Icon(Icons.person),
                            title: Text(driver!.name),
                            subtitle: const Text('Nombre'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.credit_card),
                            title: Text(driver!.idNumber),
                            subtitle: const Text('Cédula'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.directions_car),
                            title: Text(driver!.plateNumber),
                            subtitle: const Text('Placa del Vehículo'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.qr_code),
                            title: Text(driver!.code),
                            subtitle: const Text('Código'),
                          ),
                          ListTile(
                            leading: Icon(
                              driver!.isActive ? Icons.circle : Icons.circle_outlined,
                              color: driver!.isActive ? Colors.green : Colors.grey,
                            ),
                            title: Text(driver!.isActive ? 'Activo' : 'Inactivo'),
                            subtitle: const Text('Estado'),
                          ),
                          if (driver!.lastSpeed != null)
                            ListTile(
                              leading: const Icon(Icons.speed),
                              title: Text(
                                '${driver!.lastSpeed!.toStringAsFixed(1)} km/h',
                                style: TextStyle(
                                  color: driver!.lastSpeed! > 60 ? Colors.red : Colors.green,
                                ),
                              ),
                              subtitle: const Text('Última velocidad'),
                            ),
                          if (driver!.lastLatitude != null && driver!.lastLongitude != null)
                            ListTile(
                              leading: const Icon(Icons.location_on),
                              title: Text(
                                '${driver!.lastLatitude!.toStringAsFixed(4)}, ${driver!.lastLongitude!.toStringAsFixed(4)}',
                              ),
                              subtitle: const Text('Última ubicación'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/map_focused',
                          arguments: {'driver': driver},
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Ver en Mapa'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}