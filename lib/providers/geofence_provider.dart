import 'package:flutter/foundation.dart';
import '../models/geofence.dart';
import '../database/geofence_dao.dart';

class GeofenceProvider with ChangeNotifier {
  final GeofenceDao _geofenceDao = GeofenceDao();

  List<Geofence> _geofences = [];
  bool _isLoading = false;
  String? _error;

  List<Geofence> get geofences => _geofences;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadGeofences() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      _geofences = await _geofenceDao.getAllGeofences();
    } catch (e) {
      _error = 'Error cargando geocercas: $e';
      print('Error loading geofences: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addGeofence(Geofence geofence) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final id = await _geofenceDao.insertGeofence(geofence);
      geofence.id = id;
      _geofences.add(geofence);
      
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error agregando geocerca: $e';
      print('Error adding geofence: $e');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateGeofence(Geofence geofence) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Aquí necesitarías un método updateGeofence en GeofenceDao
      // Por ahora, actualizar en la lista local
      final index = _geofences.indexWhere((g) => g.id == geofence.id);
      if (index != -1) {
        _geofences[index] = geofence;
        _error = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = 'Error actualizando geocerca: $e';
      print('Error updating geofence: $e');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteGeofence(int id) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _geofenceDao.deleteGeofence(id);
      _geofences.removeWhere((g) => g.id == id);
      
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error eliminando geocerca: $e';
      print('Error deleting geofence: $e');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Geofence? getGeofenceById(int id) {
    try {
      return _geofences.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Geofence> getCircularGeofences() {
    return _geofences.where((g) => g.type == 'circle').toList();
  }

  List<Geofence> getPolygonalGeofences() {
    return _geofences.where((g) => g.type == 'polygon').toList();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}