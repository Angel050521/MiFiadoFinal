import 'dart:convert';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class CloudflareService {
  static const String _baseUrl = 'https://fiadosync.angel050521.workers.dev';
  static const String _apiKey = '6e5d6f1e-5a1f-4c3d-9b8c-7d9e8f0a1b2c';

  // Headers protegidos
  static Future<Map<String, String>> _getHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      // Siempre usar la API key para autenticación
      // ya que el token JWT generado en el cliente no es válido para autenticación
      final authToken = _apiKey.trim();
      
      // Solo mostrar los primeros 5 caracteres del token en los logs por seguridad
      final tokenPreview = authToken.length > 5 
          ? '${authToken.substring(0, 5)}...' 
          : authToken;
      
      print('🔑 Usando API Key para autenticación:');
      print('   - User ID: $userId');
      print('   - Token: $tokenPreview (longitud: ${authToken.length})');
      
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
        'X-User-Id': userId ?? '', // Incluir el ID de usuario en los headers
      };
    } catch (e) {
      print('❌ Error en _getHeaders: $e');
      // En caso de error, devolver solo los headers básicos con la API key
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${_apiKey.trim()}',
      };
    }
  }

  // Headers públicos (sin Authorization)
  static Map<String, String> _getPublicHeaders() {
    return {
      'Content-Type': 'application/json',
    };
  }
  
  // Generar una cadena aleatoria para el ID del token
  static String _generateRandomString(int length) {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        length, 
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
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
      print('🔑 Iniciando sesión con email: ${email.toLowerCase()}');
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('deviceId') ?? 'unknown';

      print('🌐 Enviando solicitud de inicio de sesión...');
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: _getPublicHeaders(),
        body: jsonEncode({
          'email': email.toLowerCase(),
          'password': password,
          'dispositivo': deviceId,
        }),
      );

      print('📥 Respuesta del servidor: ${response.statusCode}');
      print('📄 Cuerpo de la respuesta: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔑 Datos de respuesta: $data');
        
        // Validar que los datos requeridos estén presentes
        if (data['id'] == null || data['nombre'] == null) {
          print('❌ Error: Datos de usuario incompletos en la respuesta');
          return null;
        }
        
        // Generar un token JWT temporal si el servidor no proporciona uno
        String? token = data['token'] ?? data['accessToken'];
        bool hasValidToken = false;
        
        // Debug: Mostrar todas las claves en la respuesta
        print('🔍 Claves en la respuesta: ${data.keys.toList()}');
        
        if (token != null && token.isNotEmpty) {
          print('🔑 Token recibido del servidor: ${token.length > 20 ? '${token.substring(0, 20)}...' : token} (longitud: ${token.length})');
          hasValidToken = token.length > 20; // Un JWT típico es más largo
        } else {
          print('⚠️ El servidor no devolvió un token JWT. Generando uno temporal en el cliente...');
        }
        
        // Si no hay token o no es válido, generar uno nuevo
        if (!hasValidToken) {
          
          try {
            // Generar un token JWT simple en el cliente (solución temporal)
            final userId = data['id']?.toString() ?? 'unknown';
            final userName = data['nombre']?.toString() ?? 'Usuario';
            final userEmail = email.toLowerCase();
            final now = DateTime.now();
            final expiry = now.add(Duration(days: 30)); // Token válido por 30 días
            
            // Crear el payload del token
            final payload = {
              'sub': userId,
              'name': userName,
              'email': userEmail,
              'iat': now.millisecondsSinceEpoch ~/ 1000,
              'exp': expiry.millisecondsSinceEpoch ~/ 1000,
              'jti': _generateRandomString(32), // ID único para el token
            };
            
            // Codificar el payload a JSON y luego a Base64Url
            final header = jsonEncode({'typ': 'JWT', 'alg': 'HS256'});
            final encodedHeader = base64Url.encode(utf8.encode(header)).replaceAll('=', '');
            final encodedPayload = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll('=', '');
            
            // Crear firma (en un entorno real, esto debería hacerse en el backend con una clave secreta segura)
            // NOTA: Esta es una solución temporal y NO es segura para producción
            final secretKey = 'tu_clave_secreta_muy_larga_y_segura_${_apiKey}';
            final signature = base64Url.encode(utf8.encode(
              '$encodedHeader.$encodedPayload.$secretKey',
            )).replaceAll('=', '');
            
            // Construir el token JWT
            token = '$encodedHeader.$encodedPayload.$signature';
            hasValidToken = true;
            
            print('🔐 Token JWT generado en el cliente (solución temporal)');
          } catch (e) {
            print('❌ Error al generar token JWT: $e');
            // En caso de error, usar un token simple como respaldo
            token = 'generated_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(16)}';
          }
        } else {
          print('🔑 Token JWT recibido del servidor');
          // Asegurarnos de que token no sea nulo
          token ??= 'valid_${_generateRandomString(16)}';
        }
        
        // Asegurarnos de que token no sea nulo
        final tokenToSave = token ?? 'fallback_${_generateRandomString(32)}';
        
        // Guardar datos en SharedPreferences
        try {
          await Future.wait([
            prefs.setString('userId', data['id']?.toString() ?? 'unknown'),
            prefs.setString('userEmail', email.toLowerCase()),
            prefs.setString('token', tokenToSave),
            prefs.setString('userName', data['nombre']?.toString() ?? 'Usuario'),
          ]);
          
          // Verificar que los datos se guardaron correctamente
          final savedToken = prefs.getString('token');
          final savedUserId = prefs.getString('userId');
          
          print('✅ Datos guardados en SharedPreferences:');
          print('   - userId: ${data['id']} (guardado: $savedUserId)');
          print('   - userEmail: $email');
          print('   - userName: ${data['nombre']}');
          
          // Manejo seguro de token nulo en los logs
          if (tokenToSave.isNotEmpty) {
            print('   - token: ${tokenToSave.length > 20 ? '${tokenToSave.substring(0, 20)}...' : tokenToSave} (longitud: ${tokenToSave.length})');
          } else {
            print('   - token: VACÍO (longitud: 0)');
          }
          
          print('   - token guardado: ${savedToken != null ? 'Sí' : 'No'} (longitud: ${savedToken?.length ?? 0})');
          
          if (savedToken == null || savedToken.isEmpty) {
            print('❌ Error: El token no se guardó correctamente en SharedPreferences');
          }
        } catch (e) {
          print('❌ Error al guardar en SharedPreferences: $e');
          rethrow;
        }
        
        return data;
      } else {
        final error = jsonDecode(response.body);
        print('❌ Error al iniciar sesión (${response.statusCode}): ${error['error'] ?? response.body}');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Excepción al iniciar sesión: $e');
      print('Stack trace: $stackTrace');
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

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/api/suscripciones'),
        headers: headers, // SÍ Authorization
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

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/suscripciones?userId=$userId'),
        headers: headers, // SÍ Authorization
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

      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/api/usuarios/$userId/datos'),
        headers: headers, // SÍ Authorization
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
