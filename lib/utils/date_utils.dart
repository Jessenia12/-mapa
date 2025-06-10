// lib/utils/date_utils.dart
import 'package:intl/intl.dart';

class DateUtilsHelper {
  /// Devuelve una fecha formateada como "dd/MM/yyyy HH:mm"
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  /// Devuelve una fecha corta como "dd MMM yyyy"
  static String formatShortDate(DateTime dateTime) {
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  /// Devuelve la diferencia entre dos fechas en formato legible (ej: "hace 3 minutos")
  static String timeAgo(DateTime dateTime) {
    final Duration diff = DateTime.now().difference(dateTime);

    if (diff.inSeconds < 60) return 'hace unos segundos';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays < 7) return 'hace ${diff.inDays} d';
    return formatShortDate(dateTime);
  }
}
