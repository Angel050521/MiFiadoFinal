import 'package:shared_preferences/shared_preferences.dart';

class SuscripcionService {
  static const String _prefsKey = 'suscripcion_actual';

  // Guardar la suscripción actual en SharedPreferences
  static Future<void> guardarSuscripcionActual(Map<String, dynamic> suscripcion) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString(_prefsKey, jsonEncode(suscripcion));
  }

  // Obtener la suscripción actual de SharedPreferences
  static Future<Map<String, dynamic>?> obtenerSuscripcionActual() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_prefsKey);
    if (jsonString == null) return null;
    return Map<String, dynamic>.from(jsonDecode(jsonString));
  }

  // Verificar acceso a nube
  static Future<bool> tieneAccesoNube() async {
    final suscripcion = await obtenerSuscripcionActual();
    if (suscripcion == null) return false;
    return ['nube', 'premium'].contains(suscripcion['plan']);
  }

  // Verificar acceso a múltiples dispositivos
  static Future<bool> puedeUsarMultiplesDispositivos() async {
    final suscripcion = await obtenerSuscripcionActual();
    return suscripcion != null && suscripcion['plan'] == 'premium';
  }
}
