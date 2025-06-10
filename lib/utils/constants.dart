// utils/constants.dart
import 'package:flutter/material.dart';

class AppColors {
  static const primary = Colors.blue;
  static const accent = Colors.orange;
  static const danger = Colors.red;
  static const success = Colors.green;
}

class AppStrings {
  static const appName = 'GPS Tracker';
  static const defaultGeofenceName = 'Nueva Geocerca';
}

class AppConfig {
  // ⚠️ CAMBIA ESTAS COORDENADAS POR LAS DE TU CIUDAD ⚠️
  static const double defaultLatitude = -0.2298500;  // Quito, Ecuador
  static const double defaultLongitude = -78.5249500;
  
  // ⚠️ SI TIENES SERVIDOR, CAMBIA ESTA URL ⚠️
  static const String apiBaseUrl = 'http://localhost:3000/api';
  
  static const double defaultZoom = 12.0;
  static const String googleMapsApiKey = 'AIzaSyBOti4mM-6x9WDnZIjIeyb-ZWCLD46k_I4';
}