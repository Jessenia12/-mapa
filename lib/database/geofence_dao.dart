import 'package:sqflite/sqflite.dart';
import '../models/geofence.dart';
import 'db_helper.dart';

class GeofenceDao {
  final table = 'geofences';

  Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        type TEXT,
        centerLat REAL,
        centerLng REAL,
        radius REAL,
        polygonPoints TEXT
      )
    ''');
  }

  Future<int> insertGeofence(Geofence geofence) async {
    final db = await DBHelper.database;
    return await db.insert(table, geofence.toMap());
  }

  Future<List<Geofence>> getAllGeofences() async {
    final db = await DBHelper.database;
    final maps = await db.query(table);
    return maps.map((map) => Geofence.fromMap(map)).toList();
  }

  Future<int> deleteGeofence(int id) async {
    final db = await DBHelper.database;
    return await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
