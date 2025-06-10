import 'package:sqflite/sqflite.dart';
import '../models/location.dart';
import 'db_helper.dart';

class LocationDao {
  final table = 'locations';

  Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL,
        longitude REAL,
        timestamp TEXT,
        speed REAL,
        driverCode TEXT
      )
    ''');
  }

  Future<int> insertLocation(Location location) async {
    final db = await DBHelper.database;
    return await db.insert(table, location.toMap());
  }

  Future<List<Location>> getAllLocations() async {
    final db = await DBHelper.database;
    final maps = await db.query(table);
    return maps.map((map) => Location.fromMap(map)).toList();
  }

  Future<List<Location>> getLocationsByDriver(String driverCode) async {
    final db = await DBHelper.database;
    final maps = await db.query(
      table,
      where: 'driverCode = ?',
      whereArgs: [driverCode],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => Location.fromMap(map)).toList();
  }

  Future<Location?> getLastLocation(String driverCode) async {
    final db = await DBHelper.database;
    final maps = await db.query(
      table,
      where: 'driverCode = ?',
      whereArgs: [driverCode],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Location.fromMap(maps.first);
    }
    return null;
  }
}
