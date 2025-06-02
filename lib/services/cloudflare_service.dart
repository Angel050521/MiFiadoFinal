import 'dart:convert';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class CloudflareService {
  static const String _baseUrl = 'https://fiadosync.angel050521.workers.dev';
  static const String _apiKey = '6e5d6f1e-5a1f-4c3d-9b8c-7d9e8f0a1b2c';

  // Headers protegidos para autenticación
  static Future<Map<String, String>> _getHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      var token = prefs.getString('token');
      
      // Si no hay token, usar la API key como respaldo
      if (token == null || token.isEmpty) {
        print('⚠️ No se encontró token de autenticación, usando API key');
        token = _apiKey;
      }
      
      // Mostrar información de depuración (sin exponer el token completo)
      final tokenPreview = token.length > 5 
          ? '${token.substring(0, 5)}...' 
          : token;
      
      print('🔑 Configurando headers de autenticación:');
      print('   - User ID: $userId');
      print('   - Token: $tokenPreview (longitud: ${token.length})');
      
      // Crear los headers con el token de autenticación
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      
      // Añadir el ID de usuario si está disponible
      if (userId != null && userId.isNotEmpty) {
        headers['X-User-Id'] = userId;
      }
      
      return headers;
    } catch (e) {
      print('❌ Error en _getHeaders: $e');
      // En caso de error, devolver solo los headers básicos con la API key
      return {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
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

  // Iniciar sesión de usuario
  static Future<Map<String, dynamic>?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      print('🔑 Iniciando sesión con email: ${email.toLowerCase()}');
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('deviceId') ?? 'unknown';

      print('🌐 Enviando solicitud de inicio de sesión...');
      
      // Usar la API key para autenticar la petición de login
      final headers = _getPublicHeaders();
      headers['Authorization'] = 'Bearer $_apiKey';
      
      print('🔑 Usando API Key para autenticación en login');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/usuarios/login'),
        headers: headers,
        body: jsonEncode({
          'email': email.toLowerCase(),
          'password': password,
          'dispositivo': deviceId,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📥 Respuesta del servidor: ${response.statusCode}');
      print('📄 Cuerpo de la respuesta: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔑 Datos de respuesta: $data');
        
        // Validar que los datos requeridos estén presentes
        if (data['id'] == null || data['email'] == null) {
          print('❌ Error: Datos de usuario incompletos en la respuesta');
          return null;
        }
        
        // Obtener el token JWT de la respuesta
        final token = data['token'] ?? data['accessToken'];
        
        if (token == null || token.isEmpty) {
          print('❌ Error: No se recibió un token JWT en la respuesta');
          return null;
        }
        
        print('🔑 Token recibido: ${token.length > 10 ? '${token.substring(0, 10)}...' : token} (longitud: ${token.length})');
        
        // Verificar que el token sea un JWT válido
        try {
          final isTokenValid = JwtDecoder.isExpired(token) == false;
          if (!isTokenValid) {
            print('❌ Error: Token JWT expirado o inválido');
            return null;
          }
          
          // Decodificar el token para obtener información del usuario
          final Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
          print('🔍 Token decodificado: $decodedToken');
          
          // Obtener datos del usuario del token o de la respuesta
          final userId = (decodedToken['sub'] ?? data['id'] ?? '').toString();
          final userEmail = decodedToken['email'] ?? data['email'] ?? '';
          final userName = decodedToken['name'] ?? data['nombre']?.toString() ?? 'Usuario';
          final userPlan = decodedToken['plan'] ?? data['plan']?.toString() ?? 'free';
          
          if (userId.isEmpty || userEmail.isEmpty) {
            print('❌ Error: Token JWT no contiene información de usuario válida');
            return null;
          }
          
          // Guardar los datos del usuario en SharedPreferences
          await prefs.setString('userId', userId);
          await prefs.setString('userEmail', userEmail);
          await prefs.setString('token', token);
          await prefs.setString('userName', userName);
          await prefs.setString('plan', userPlan);
          
          // Verificar que los datos se guardaron correctamente
          final savedToken = prefs.getString('token');
          final savedUserId = prefs.getString('userId');
          
          print('✅ Datos guardados en SharedPreferences:');
          print('   - userId: $userId (guardado: $savedUserId)');
          print('   - userEmail: $userEmail');
          print('   - userName: $userName');
          print('   - plan: $userPlan');
          print('   - token guardado: ${savedToken != null ? 'Sí' : 'No'} (longitud: ${savedToken?.length ?? 0})');
          
          if (savedToken == null || savedToken.isEmpty) {
            print('⚠️ Advertencia: El token no se guardó correctamente');
            return null;
          }
          
          return {
            'id': userId,
            'email': userEmail,
            'nombre': userName,
            'plan': userPlan,
            'token': token,
          };
        } catch (e) {
          print('❌ Error al procesar el token JWT: $e');
          return null;
        }
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
