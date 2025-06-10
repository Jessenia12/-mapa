import 'package:sqflite/sqflite.dart';
import '../models/vehicle.dart';
import 'db_helper.dart';

class VehicleDao {
  final table = 'vehicles';

  Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        license_plate TEXT,
        model TEXT,
        brand TEXT,
        year INTEGER,
        color TEXT,
        driver_code TEXT
      )
    ''');
  }

  Future<int> insertVehicle(Vehicle vehicle) async {
    final db = await DBHelper.database;
    return await db.insert(table, vehicle.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Vehicle>> getAllVehicles() async {
    final db = await DBHelper.database;
    final maps = await db.query(table, orderBy: 'license_plate ASC');
    return maps.map((map) => Vehicle.fromMap(map)).toList();
  }

  Future<Vehicle?> getVehicleById(int id) async {
    final db = await DBHelper.database;
    final maps = await db.query(table, where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Vehicle.fromMap(maps.first);
    }
    return null;
  }

  Future<Vehicle?> getVehicleByDriverCode(String driverCode) async {
    final db = await DBHelper.database;
    final maps = await db.query(table, where: 'driver_code = ?', whereArgs: [driverCode]);
    if (maps.isNotEmpty) {
      return Vehicle.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateVehicle(Vehicle vehicle) async {
    final db = await DBHelper.database;
    return await db.update(
      table,
      vehicle.toMap(),
      where: 'id = ?',
      whereArgs: [vehicle.id],
    );
  }

  Future<int> deleteVehicle(int id) async {
    final db = await DBHelper.database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}