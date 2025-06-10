import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static SharedPreferences? _prefs;

  /// Inicializa SharedPreferences (debe llamarse una vez al inicio)
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Guarda un valor tipo String
  static Future<void> saveString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  /// Obtiene un valor tipo String
  static Future<String?> getString(String key) async {
    return _prefs?.getString(key);
  }

  /// Elimina todos los datos guardados
  static Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
