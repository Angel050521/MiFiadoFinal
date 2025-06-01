import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class NubeService {
  static const String baseUrl = 'https://fiadosync.angel050521.workers.dev';

  /// 🔄 Actualiza el plan de un usuario en la nube
  static Future<Map<String, dynamic>> actualizarPlan({
    required String userId,
    required String plan,
  }) async {
    final url = Uri.parse('$baseUrl/api/actualizar_plan');
    print('🔄 Intentando actualizar plan a $plan para usuario $userId');

    try {
      // Usar la API key directamente para autenticación
      final apiKey = '6e5d6f1e-5a1f-4c3d-9b8c-7d9e8f0a1b2c';
      
      print('🔑 Usando API Key para autenticación');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'X-User-Id': userId, // Incluir el ID de usuario en los headers
        },
        body: jsonEncode({
          'userId': userId,
          'plan': plan,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📥 Respuesta del servidor (${response.statusCode}): ${response.body}');
      
      // Intentar decodificar el cuerpo de la respuesta
      late final dynamic responseBody;
      try {
        responseBody = jsonDecode(response.body);
      } catch (e) {
        print('⚠️ No se pudo decodificar la respuesta JSON: ${response.body}');
        responseBody = {'error': 'Respuesta del servidor no válida'};
      }
      
      if (response.statusCode == 200) {
        print('✅ Plan actualizado exitosamente');
        return {
          'success': true, 
          'message': 'Plan actualizado correctamente',
          'data': responseBody,
        };
      } else if (response.statusCode == 401) {
        // Token expirado o inválido
        print('🔐 Error de autenticación (401): ${response.body}');
        return {
          'success': false, 
          'error': 'Tu sesión ha expirado. Por favor, inicia sesión de nuevo.',
          'statusCode': 401,
        };
      } else {
        // Otros errores
        final errorMsg = responseBody is Map ? responseBody['error']?.toString() ?? 'Error desconocido' : 'Error en el servidor';
        print('❌ Error al actualizar plan (${response.statusCode}): $errorMsg');
        return {
          'success': false, 
          'error': errorMsg,
          'statusCode': response.statusCode,
          'response': responseBody,
        };
      }
    } on http.ClientException catch (e) {
      final error = 'Error de conexión: ${e.message}';
      print('❌ $error');
      return {'success': false, 'error': error};
    } on TimeoutException {
      const error = 'Tiempo de espera agotado al actualizar el plan';
      print('❌ $error');
      return {'success': false, 'error': error};
    } catch (e, stackTrace) {
      final error = 'Error inesperado en actualizarPlan: $e\n$stackTrace';
      print('❌ $error');
      return {'success': false, 'error': 'Error inesperado: ${e.toString()}'};
    }
  }

  /// 🔄 Envía los datos a la nube (clientes, productos y movimientos)
  static Future<Map<String, dynamic>> sincronizarConNube({
    required String userId,
    required String token,
    required List<Map<String, dynamic>> clientes,
    required List<Map<String, dynamic>> productos,
    required List<Map<String, dynamic>> movimientos,
  }) async {
    final url = Uri.parse('$baseUrl/upload');
    print('🔄 Iniciando sincronización para usuario $userId');
    print('📊 Datos a sincronizar - Clientes: ${clientes.length}, Productos: ${productos.length}, Movimientos: ${movimientos.length}');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': userId,
          'clientes': clientes,
          'productos': productos,
          'movimientos': movimientos,
        }),
      ).timeout(const Duration(seconds: 15));

      final responseBody = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        print('✅ Sincronización exitosa: ${response.body}');
        return {'success': true, 'data': responseBody};
      } else {
        final errorMsg = responseBody['error'] ?? 'Error desconocido';
        print('❌ Error en sincronización (${response.statusCode}): $errorMsg');
        return {
          'success': false, 
          'error': 'Error ${response.statusCode}: $errorMsg',
          'statusCode': response.statusCode,
        };
      }
    } on http.ClientException catch (e) {
      final error = 'Error de conexión al sincronizar: ${e.message}';
      print('❌ $error');
      return {'success': false, 'error': error};
    } on TimeoutException {
      const error = 'Tiempo de espera agotado durante la sincronización';
      print('❌ $error');
      return {'success': false, 'error': error};
    } catch (e, stackTrace) {
      final error = 'Error inesperado en sincronizarConNube: $e\n$stackTrace';
      print('❌ $error');
      return {'success': false, 'error': 'Error al sincronizar: ${e.toString()}'};
    }
  }

  /// ⬇️ Descarga datos de la nube (clientes, productos y movimientos)
  static Future<Map<String, dynamic>> descargarDesdeNube({
    required String userId,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/download?userId=$userId');
    print('⬇️ Iniciando descarga para usuario $userId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Descarga exitosa: ${data.length} elementos recibidos');
        return {
          'success': true,
          'data': {
            'clientes': data['clientes'] ?? [],
            'productos': data['productos'] ?? [],
            'movimientos': data['movimientos'] ?? [],
          }
        };
      } else {
        final errorMsg = jsonDecode(response.body)['error'] ?? 'Error desconocido';
        print('❌ Error al descargar (${response.statusCode}): $errorMsg');
        return {
          'success': false,
          'error': 'Error ${response.statusCode}: $errorMsg',
          'statusCode': response.statusCode,
        };
      }
    } on http.ClientException catch (e) {
      final error = 'Error de conexión al descargar: ${e.message}';
      print('❌ $error');
      return {'success': false, 'error': error};
    } on TimeoutException {
      const error = 'Tiempo de espera agotado durante la descarga';
      print('❌ $error');
      return {'success': false, 'error': error};
    } catch (e, stackTrace) {
      final error = 'Error inesperado en descargarDesdeNube: $e\n$stackTrace';
      print('❌ $error');
      return {'success': false, 'error': 'Error al descargar: ${e.toString()}'};
    }
  }

  /// ✅ Verifica si el deviceId actual está autorizado o si se requiere migración
  static Future<Map<String, dynamic>> validarODeseaMigrar({
    required String userId,
    required String token,
    required String deviceId,
  }) async {
    final url = Uri.parse('$baseUrl/validar_device');
    print('🔍 Validando dispositivo $deviceId para usuario $userId');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': userId,
          'deviceId': deviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      final responseBody = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        print('✅ Validación de dispositivo exitosa: ${response.body}');
        return {'success': true, 'permitido': responseBody['permitido'] == true};
      } else {
        final errorMsg = responseBody['error'] ?? 'Error desconocido';
        print('❌ Error al validar dispositivo (${response.statusCode}): $errorMsg');
        return {
          'success': false,
          'error': 'Error ${response.statusCode}: $errorMsg',
          'statusCode': response.statusCode,
        };
      }
    } on http.ClientException catch (e) {
      final error = 'Error de conexión al validar dispositivo: ${e.message}';
      print('❌ $error');
      return {'success': false, 'error': error};
    } on TimeoutException {
      const error = 'Tiempo de espera agotado al validar dispositivo';
      print('❌ $error');
      return {'success': false, 'error': error};
    } catch (e, stackTrace) {
      final error = 'Error inesperado en validarODeseaMigrar: $e\n$stackTrace';
      print('❌ $error');
      return {'success': false, 'error': 'Error al validar dispositivo: ${e.toString()}'};
    }
  }

  /// 🛠️ Actualiza el deviceId en la nube (si el usuario desea migrar)
  static Future<Map<String, dynamic>> actualizarDevice({
    required String userId,
    required String token,
    required String deviceId,
  }) async {
    final url = Uri.parse('$baseUrl/actualizar_device');
    print('🔄 Actualizando dispositivo a $deviceId para usuario $userId');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': userId,
          'deviceId': deviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      final responseBody = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        print('✅ Dispositivo actualizado exitosamente: ${response.body}');
        return {'success': true};
      } else {
        final errorMsg = responseBody['error'] ?? 'Error desconocido';
        print('❌ Error al actualizar dispositivo (${response.statusCode}): $errorMsg');
        return {
          'success': false,
          'error': 'Error ${response.statusCode}: $errorMsg',
          'statusCode': response.statusCode,
        };
      }
    } on http.ClientException catch (e) {
      final error = 'Error de conexión al actualizar dispositivo: ${e.message}';
      print('❌ $error');
      return {'success': false, 'error': error};
    } on TimeoutException {
      const error = 'Tiempo de espera agotado al actualizar dispositivo';
      print('❌ $error');
      return {'success': false, 'error': error};
    } catch (e, stackTrace) {
      final error = 'Error inesperado en actualizarDevice: $e\n$stackTrace';
      print('❌ $error');
      return {'success': false, 'error': 'Error al actualizar dispositivo: ${e.toString()}'};
    }
  }
}
