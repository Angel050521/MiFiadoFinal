import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CloudflareService {
  static const String _baseUrl = 'https://fiadosync.angel050521.workers.dev';
  static const String _apiKey = '6e5d6f1e-5a1f-4c3d-9b8c-7d9e8f0a1b2c';

  // Headers protegidos
  static Map<String, String> _getHeaders() {
    final apiKey = _apiKey.trim();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  // Headers públicos (sin Authorization)
  static Map<String, String> _getPublicHeaders() {
    return {
      'Content-Type': 'application/json',
    };
  }

  // Registrar un nuevo usuario
  static Future<Map<String, dynamic>?> registerUser({
    required String nombre,
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('deviceId') ?? 'unknown';

      final response = await http.post(
        Uri.parse('$_baseUrl/api/usuarios'),
        headers: _getPublicHeaders(), // SIN Authorization
        body: jsonEncode({
          'nombre': nombre,
          'email': email.toLowerCase(),
          'password': password,
          'dispositivo': deviceId,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await prefs.setString('userId', data['id'].toString());
        await prefs.setString('userEmail', email.toLowerCase());
        await prefs.setString('token', password);
        await prefs.setString('userName', nombre);
        print('✅ Usuario registrado correctamente');
        return data;
      } else {
        print('❌ Error al registrar usuario: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al registrar usuario: $e');
      return null;
    }
  }

  // Iniciar sesión con un usuario existente
  static Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('deviceId') ?? 'unknown';

      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: _getPublicHeaders(), // SIN Authorization
        body: jsonEncode({
          'email': email.toLowerCase(),
          'password': password,
          'dispositivo': deviceId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('userId', data['id'].toString());
        await prefs.setString('userEmail', email.toLowerCase());
        await prefs.setString('token', password);
        await prefs.setString('userName', data['nombre']);
        print('✅ Inicio de sesión exitoso');
        return data;
      } else {
        print('❌ Error al iniciar sesión: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al iniciar sesión: $e');
      return null;
    }
  }

  // Registrar o iniciar sesión con Google (aquí depende si tu backend requiere auth o no)
  static Future<Map<String, dynamic>?> loginWithGoogle({
    required String googleId,
    required String nombre,
    required String email,
    String? photoUrl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('deviceId') ?? 'unknown';

      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/google'),
        headers: _getPublicHeaders(), // Normalmente no requiere Authorization
        body: jsonEncode({
          'googleId': googleId,
          'nombre': nombre,
          'email': email.toLowerCase(),
          'photoUrl': photoUrl,
          'dispositivo': deviceId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await prefs.setString('userId', data['id'].toString());
        await prefs.setString('userEmail', email.toLowerCase());
        await prefs.setString('token', 'google_$googleId');
        await prefs.setString('userName', nombre);
        await prefs.setString('authType', 'google');
        print('✅ Inicio de sesión con Google exitoso');
        return data;
      } else {
        print('❌ Error al iniciar sesión con Google: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al iniciar sesión con Google: $e');
      return null;
    }
  }

  static Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final token = prefs.getString('token');
    return userId != null && token != null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    await prefs.remove('userEmail');
    await prefs.remove('token');
    await prefs.remove('userName');
    await prefs.remove('authType');
  }

  // Enviar datos de suscripción (PROTEGIDO, SÍ usa Authorization)
  static Future<bool> sendSubscriptionData({
    required String plan,
    required DateTime fechaInicio,
    required DateTime fechaVencimiento,
    required String estado,
    String? tokenPago,
    String? idUsuario,
    String? email,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('deviceId') ?? 'unknown';
      idUsuario ??= prefs.getString('userId');
      email ??= prefs.getString('userEmail');

      if (idUsuario == null || email == null) {
        print('❌ Error: Usuario no autenticado para guardar suscripción');
        return false;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/api/suscripciones'),
        headers: _getHeaders(), // SÍ Authorization
        body: jsonEncode({
          'plan': plan,
          'fechaInicio': fechaInicio.toIso8601String(),
          'fechaVencimiento': fechaVencimiento.toIso8601String(),
          'estado': estado,
          'tokenPago': tokenPago,
          'idUsuario': idUsuario,
          'email': email,
          'dispositivo': deviceId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Datos de suscripción guardados en Cloudflare D1');
        return true;
      } else {
        print('❌ Error al guardar en Cloudflare D1: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Excepción al conectar con Cloudflare: $e');
      return false;
    }
  }

  // Verificar estado de suscripción (PROTEGIDO, SÍ usa Authorization)
  static Future<Map<String, dynamic>?> checkSubscriptionStatus(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      userId ??= prefs.getString('userId');

      if (userId == null) {
        print('❌ Error: No hay usuario para verificar suscripción');
        return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/suscripciones?userId=$userId'),
        headers: _getHeaders(), // SÍ Authorization
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data.isNotEmpty ? data[0] : null;
      } else {
        print('❌ Error al verificar suscripción: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al verificar suscripción: $e');
      return null;
    }
  }

  // Sincronizar datos desde la nube (PROTEGIDO, SÍ usa Authorization)
  static Future<Map<String, dynamic>?> syncUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      if (userId == null) {
        print('❌ Error: Usuario no autenticado para sincronizar datos');
        return null;
      }

      final response = await http.get(
        Uri.parse('$_baseUrl/api/usuarios/$userId/datos'),
        headers: _getHeaders(), // SÍ Authorization
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print('❌ Error al sincronizar datos: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al sincronizar datos: $e');
      return null;
    }
  }
}
