import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'screens/dashboard_screen.dart';
import 'providers/fleet_provider.dart';
import 'providers/geofence_provider.dart';
import 'providers/gps_provider.dart';

import 'database/db_helper.dart';
import 'services/api_service.dart';
import 'services/geofence_service.dart';
import 'services/gps_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/vehicle_service.dart';

import 'app.dart';

Future<void> main() async {
  // Asegura que Flutter esté correctamente inicializado
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Solicita permisos necesarios antes de continuar
    await _requestPermissions();

    // Inicializa y corrige la base de datos antes de los otros servicios
    await _initializeDatabase();

    // Inicializa servicios importantes antes de correr la app
    await NotificationService.initialize();
    await StorageService.init();

    runApp(MyApp());
  } catch (e, stack) {
    // Puedes loggear el error o mostrar una pantalla de error
    debugPrint('Error durante la inicialización: $e');
    debugPrint('$stack');
    
    // En caso de error crítico de DB, intentar reinicializar
    try {
      debugPrint('Intentando reinicializar base de datos...');
      await DBHelper.reinitializeDatabase();
      runApp(MyApp());
    } catch (dbError) {
      debugPrint('Error crítico de base de datos: $dbError');
      // Aquí podrías mostrar una pantalla de error o crashear controladamente
      runApp(ErrorApp(error: dbError.toString()));
    }
  }
}

// Método para inicializar y corregir la base de datos
Future<void> _initializeDatabase() async {
  try {
    debugPrint('Inicializando base de datos...');
    
    // Inicializar la base de datos
    final db = await DBHelper.database;
    
    // Obtener información de la base de datos
    final info = await DBHelper.getDatabaseInfo();
    debugPrint('Información de DB: $info');
    
    // Verificar si la tabla drivers existe y tiene las columnas necesarias
    final tableExists = await DBHelper.tableExists('drivers');
    
    if (!tableExists) {
      debugPrint('Tabla drivers no existe, se creará automáticamente');
      return; // onCreate se encargará de crear las tablas
    }
    
    // Verificar columnas existentes
    final columns = await DBHelper.getTableColumns('drivers');
    debugPrint('Columnas actuales en drivers: $columns');
    
    // Lista de columnas requeridas
    final requiredColumns = [
      'code', 'driver_code', 'idNumber', 'plateNumber', 
      'isActive', 'currentStatus', 'lastConnection',
      'lastLatitude', 'lastLongitude', 'lastSpeed',
      'email', 'phone', 'license_number',
      'created_at', 'updated_at'
    ];
    
    // Verificar y agregar columnas faltantes
    bool needsColumnUpdate = false;
    for (String column in requiredColumns) {
      if (!columns.contains(column)) {
        needsColumnUpdate = true;
        break;
      }
    }
    
    if (needsColumnUpdate) {
      debugPrint('Detectadas columnas faltantes, actualizando esquema...');
      await _updateDriversTableSchema(db);
    } else {
      debugPrint('Esquema de drivers está actualizado');
    }
    
  } catch (e) {
    debugPrint('Error inicializando base de datos: $e');
    
    // Si hay un error, intentar reinicializar completamente
    debugPrint('Reinicializando base de datos por error...');
    await DBHelper.reinitializeDatabase();
  }
}

// Método para actualizar el esquema de la tabla drivers
Future<void> _updateDriversTableSchema(Database db) async {
  try {
    // Definir las columnas que necesitamos agregar con sus tipos
    final columnsToAdd = {
      'code': 'TEXT',
      'driver_code': 'TEXT', 
      'idNumber': 'TEXT',
      'plateNumber': 'TEXT',
      'isActive': 'INTEGER DEFAULT 1',
      'currentStatus': 'TEXT DEFAULT "inactive"',
      'lastConnection': 'TEXT',
      'lastLatitude': 'REAL',
      'lastLongitude': 'REAL',
      'lastSpeed': 'REAL',
      'email': 'TEXT',
      'phone': 'TEXT',
      'license_number': 'TEXT',
      'created_at': 'TEXT DEFAULT CURRENT_TIMESTAMP',
      'updated_at': 'TEXT DEFAULT CURRENT_TIMESTAMP'
    };
    
    // Obtener columnas existentes
    final existingColumns = await DBHelper.getTableColumns('drivers');
    
    // Agregar cada columna faltante
    for (String columnName in columnsToAdd.keys) {
      if (!existingColumns.contains(columnName)) {
        try {
          final columnDefinition = columnsToAdd[columnName];
          await db.execute('ALTER TABLE drivers ADD COLUMN $columnName $columnDefinition');
          debugPrint('✓ Columna agregada: $columnName');
        } catch (e) {
          debugPrint('✗ Error agregando columna $columnName: $e');
          // Continuar con las otras columnas aunque una falle
        }
      }
    }
    
    debugPrint('Actualización de esquema de drivers completada');
    
  } catch (e) {
    debugPrint('Error actualizando esquema de drivers: $e');
    rethrow;
  }
}

Future<void> _requestPermissions() async {
  final permissions = [
    Permission.location,
    Permission.locationAlways,
    Permission.locationWhenInUse,
    Permission.notification,
    Permission.camera,
  ];

  final statuses = await permissions.request();

  // Verificación opcional: puedes actuar si algún permiso es denegado
  statuses.forEach((permission, status) {
    if (status.isDenied || status.isPermanentlyDenied) {
      debugPrint('Permiso denegado: $permission');
      // Aquí podrías redirigir al usuario a la configuración si es crítico
    }
  });
}

// Clase principal de la aplicación
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Provider para GPS
        ChangeNotifierProvider(
          create: (context) => GPSProvider(),
        ),
        
        // Provider para Fleet
        ChangeNotifierProvider(
          create: (context) => FleetProvider(),
        ),
        
        // Provider para Geofence
        ChangeNotifierProvider(
          create: (context) => GeofenceProvider(),
        ),
        
        // Puedes agregar más providers según necesites
        // Provider(create: (context) => ApiService()),
        // Provider(create: (context) => VehicleService()),
      ],
      child: MaterialApp(
        title: 'GPS Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          useMaterial3: true,
        ),
        home: DashboardScreen(), // Tu widget principal de la aplicación
      ),
    );
  }
}

// Widget para mostrar errores críticos
class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({Key? key, required this.error}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Error - GPS Tracker',
      home: Scaffold(
        backgroundColor: Colors.red.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red.shade600,
                ),
                const SizedBox(height: 20),
                Text(
                  'Error de Inicialización',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'La aplicación no pudo inicializarse correctamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // Reiniciar la aplicación
                    // Nota: En producción podrías usar restart_app package
                    debugPrint('Reiniciando aplicación...');
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}