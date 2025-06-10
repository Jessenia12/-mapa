import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'geofence_dao.dart';
import 'location_dao.dart';
import 'vehicle_dao.dart';
import 'driver_dao.dart';

class DBHelper {
  static Database? _database;
  
  // ACTUALIZADO: Incrementar versión para manejar migraciones
  static const int _databaseVersion = 2;
  
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }
  
  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fleet_tracking.db');
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, // AGREGADO: Manejo de migraciones
    );
  }
  
  static Future<void> _onCreate(Database db, int version) async {
    await GeofenceDao().createTable(db);
    await LocationDao().createTable(db);
    await VehicleDao().createTable(db);
    await DriverDao().createTable(db);
  }
  
  // AGREGADO: Método para manejar actualizaciones de esquema
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Actualizando base de datos de versión $oldVersion a $newVersion');
    
    // Manejar migraciones específicas por DAO
    if (oldVersion < 2) {
      // Actualizar esquema de drivers
      await DriverDao().updateTableSchema(db, oldVersion, newVersion);
      
      // Aquí puedes agregar migraciones para otras tablas si es necesario
      // await VehicleDao().updateTableSchema(db, oldVersion, newVersion);
      // await LocationDao().updateTableSchema(db, oldVersion, newVersion);
      // await GeofenceDao().updateTableSchema(db, oldVersion, newVersion);
    }
    
    // Puedes agregar más condiciones para futuras versiones
    // if (oldVersion < 3) {
    //   // Migraciones para versión 3
    // }
  }
  
  // AGREGADO: Método para obtener información de la base de datos
  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final version = await db.getVersion();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fleet_tracking.db');
    
    return {
      'version': version,
      'path': path,
      'isOpen': db.isOpen,
    };
  }
  
  // AGREGADO: Método para verificar si una tabla existe
  static Future<bool> tableExists(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName]
    );
    return result.isNotEmpty;
  }
  
  // AGREGADO: Método para obtener columnas de una tabla
  static Future<List<String>> getTableColumns(String tableName) async {
    final db = await database;
    final result = await db.rawQuery('PRAGMA table_info($tableName)');
    return result.map((column) => column['name'] as String).toList();
  }
  
  // MEJORADO: Método para cerrar base de datos con verificación
  static Future<void> closeDB() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
      print('Base de datos cerrada correctamente');
    }
  }
  
  // AGREGADO: Método para eliminar la base de datos (útil para desarrollo/testing)
  static Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fleet_tracking.db');
    
    if (_database != null) {
      await closeDB();
    }
    
    await databaseFactory.deleteDatabase(path);
    print('Base de datos eliminada: $path');
  }
  
  // AGREGADO: Método para reinicializar la base de datos
  static Future<void> reinitializeDatabase() async {
    await deleteDatabase();
    _database = await _initDB();
    print('Base de datos reinicializada');
  }
}