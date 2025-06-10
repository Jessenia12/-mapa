import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class DriverDao {
  final String table = 'drivers';

  // Método para crear la tabla con el esquema correcto
  Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        idNumber TEXT,
        plateNumber TEXT,
        code TEXT UNIQUE,
        isActive INTEGER DEFAULT 1,
        currentStatus TEXT DEFAULT 'inactive',
        lastConnection TEXT,
        lastLatitude REAL,
        lastLongitude REAL,
        lastSpeed REAL,
        email TEXT,
        phone TEXT,
        license_number TEXT,
        driver_code TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  // Método para actualizar esquema de la tabla
  Future<void> updateTableSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        // Agregar nuevas columnas si no existen
        await db.execute('ALTER TABLE $table ADD COLUMN idNumber TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN plateNumber TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN code TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN isActive INTEGER DEFAULT 1');
        await db.execute('ALTER TABLE $table ADD COLUMN currentStatus TEXT DEFAULT "inactive"');
        await db.execute('ALTER TABLE $table ADD COLUMN lastConnection TEXT');
        await db.execute('ALTER TABLE $table ADD COLUMN lastLatitude REAL');
        await db.execute('ALTER TABLE $table ADD COLUMN lastLongitude REAL');
        await db.execute('ALTER TABLE $table ADD COLUMN lastSpeed REAL');
        await db.execute('ALTER TABLE $table ADD COLUMN driver_code TEXT');
        print('Esquema de drivers actualizado de versión $oldVersion a $newVersion');
      } catch (e) {
        print('Error actualizando esquema de drivers: $e');
        // Las columnas podrían ya existir, continuar
      }
    }
  }

  // Obtener todos los conductores
  Future<List<Map<String, dynamic>>> getAllDrivers() async {
    final db = await DBHelper.database;
    return await db.query(table, orderBy: 'name ASC');
  }

  // Insertar un nuevo conductor
  Future<int> insertDriver(Map<String, dynamic> driver) async {
    final db = await DBHelper.database;
    
    // Normalizar datos para compatibilidad
    final normalizedDriver = _normalizeDriverData(driver);
    
    // Agregar timestamp de creación si no existe
    if (!normalizedDriver.containsKey('created_at')) {
      normalizedDriver['created_at'] = DateTime.now().toIso8601String();
    }
    normalizedDriver['updated_at'] = DateTime.now().toIso8601String();
    
    return await db.insert(table, normalizedDriver, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Actualizar un conductor existente
  Future<int> updateDriver(Map<String, dynamic> driver) async {
    final db = await DBHelper.database;
    
    // Normalizar datos para compatibilidad
    final normalizedDriver = _normalizeDriverData(driver);
    
    // Actualizar timestamp de modificación
    normalizedDriver['updated_at'] = DateTime.now().toIso8601String();
    
    return await db.update(
      table,
      normalizedDriver,
      where: 'id = ?',
      whereArgs: [normalizedDriver['id']],
    );
  }

  // Método privado para normalizar datos entre los dos formatos
  Map<String, dynamic> _normalizeDriverData(Map<String, dynamic> driver) {
    final normalized = Map<String, dynamic>.from(driver);
    
    // Sincronizar campos duplicados
    if (normalized.containsKey('driver_code') && !normalized.containsKey('code')) {
      normalized['code'] = normalized['driver_code'];
    }
    if (normalized.containsKey('code') && !normalized.containsKey('driver_code')) {
      normalized['driver_code'] = normalized['code'];
    }
    
    // Asegurar que isActive sea entero
    if (normalized.containsKey('isActive')) {
      if (normalized['isActive'] is bool) {
        normalized['isActive'] = normalized['isActive'] ? 1 : 0;
      }
    }
    
    return normalized;
  }

  // Eliminar un conductor
  Future<int> deleteDriver(int id) async {
    final db = await DBHelper.database;
    return await db.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Obtener conductor por ID - CORREGIDO
  Future<Map<String, dynamic>?> getDriverById(int id) async {
    final db = await DBHelper.database;
    final result = await db.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return _normalizeDriverForModel(result.first);
    }
    return null;
  }

  // Obtener conductor por código - CORREGIDO
  Future<Map<String, dynamic>?> getDriverByCode(String driverCode) async {
    final db = await DBHelper.database;
    
    // Buscar tanto en 'code' como en 'driver_code'
    final result = await db.query(
      table,
      where: 'code = ? OR driver_code = ?',
      whereArgs: [driverCode, driverCode],
      limit: 1,
    );
    
    if (result.isNotEmpty) {
      return _normalizeDriverForModel(result.first);
    }
    return null;
  }

  // Método privado para normalizar datos de DB hacia el modelo Driver
  Map<String, dynamic> _normalizeDriverForModel(Map<String, dynamic> dbData) {
    final normalized = Map<String, dynamic>.from(dbData);
    
    // Asegurar que tenemos todos los campos necesarios para el modelo Driver
    normalized['idNumber'] = normalized['idNumber'] ?? normalized['license_number'] ?? 'N/A';
    normalized['plateNumber'] = normalized['plateNumber'] ?? 'N/A';
    normalized['code'] = normalized['code'] ?? normalized['driver_code'] ?? '';
    normalized['driver_code'] = normalized['driver_code'] ?? normalized['code'] ?? '';
    normalized['isActive'] = (normalized['isActive'] ?? 1) == 1;
    normalized['currentStatus'] = normalized['currentStatus'] ?? 'inactive';
    
    return normalized;
  }

  // Buscar conductores por nombre
  Future<List<Map<String, dynamic>>> searchDriversByName(String name) async {
    final db = await DBHelper.database;
    final results = await db.query(
      table,
      where: 'name LIKE ?',
      whereArgs: ['%$name%'],
      orderBy: 'name ASC',
    );
    
    return results.map((result) => _normalizeDriverForModel(result)).toList();
  }

  // Verificar si existe un conductor con el código dado - CORREGIDO
  Future<bool> driverCodeExists(String driverCode) async {
    final db = await DBHelper.database;
    final result = await db.query(
      table,
      where: 'code = ? OR driver_code = ?',
      whereArgs: [driverCode, driverCode],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Obtener el conteo total de conductores
  Future<int> getDriversCount() async {
    final db = await DBHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Método para limpiar todos los datos (útil para desarrollo/testing)
  Future<int> deleteAllDrivers() async {
    final db = await DBHelper.database;
    return await db.delete(table);
  }

  // NUEVO: Método para actualizar ubicación del conductor
  Future<int> updateDriverLocation(int driverId, double latitude, double longitude, double speed) async {
    final db = await DBHelper.database;
    return await db.update(
      table,
      {
        'lastLatitude': latitude,
        'lastLongitude': longitude,
        'lastSpeed': speed,
        'lastConnection': DateTime.now().toIso8601String(),
        'currentStatus': 'active',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [driverId],
    );
  }

  // NUEVO: Método para obtener conductores activos
  Future<List<Map<String, dynamic>>> getActiveDrivers() async {
    final db = await DBHelper.database;
    final results = await db.query(
      table,
      where: 'isActive = ? AND currentStatus != ?',
      whereArgs: [1, 'inactive'],
      orderBy: 'lastConnection DESC',
    );
    
    return results.map((result) => _normalizeDriverForModel(result)).toList();
  }
}