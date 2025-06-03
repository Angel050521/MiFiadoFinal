import 'dart:async';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  /// 🔄 Envía los datos a la nube (clientes, productos, movimientos y pedidos)
  /// con manejo mejorado de registros eliminados
  static Future<Map<String, dynamic>> sincronizarConNube({
    required String userId,
    required String token,
    required List<Map<String, dynamic>> clientes,
    required List<Map<String, dynamic>> productos,
    required List<Map<String, dynamic>> movimientos,
    required Map<String, dynamic> deleted,
    List<Map<String, dynamic>> pedidos = const [],
  }) async {
    // Validar token
    if (token.isEmpty) {
      print('❌ [NubeService] Error: Token vacío');
      return {'success': false, 'error': 'Token de autenticación no proporcionado'};
    }
    
    // Validar userId
    if (userId.isEmpty) {
      print('❌ [NubeService] Error: userId vacío');
      return {'success': false, 'error': 'ID de usuario no proporcionado'};
    }
    final url = Uri.parse('$baseUrl/api/sync');
    print('🔄 [NubeService] Iniciando sincronización para usuario $userId');
    print('🔗 [NubeService] URL: $url');
    print('📊 [NubeService] Datos a sincronizar:');
    print('   - Clientes: ${clientes.length}');
    print('   - Productos: ${productos.length}');
    print('   - Movimientos: ${movimientos.length}');
    print('   - Eliminados:');
    print('     - Clientes: ${deleted['clientes']?.length ?? 0}');
    print('     - Productos: ${deleted['productos']?.length ?? 0}');
    print('     - Movimientos: ${deleted['movimientos']?.length ?? 0}');
    print('     - Pedidos: ${deleted['pedidos']?.length ?? 0}');
    print('🔑 [NubeService] Token: ${token.isNotEmpty ? '***${token.substring(token.length - 4)}' : 'VACÍO'}');

    try {
      // Validar datos antes de enviar
      final requestData = {
        'userId': userId,
        'clientes': clientes,
        'productos': productos,
        'movimientos': movimientos,
        'pedidos': pedidos, // Incluir pedidos en los datos a sincronizar
        'deleted': deleted.isEmpty ? {} : deleted, // Enviar objeto vacío si no hay eliminados
        'timestamp': DateTime.now().toIso8601String(),
      };      
      
      print('🔄 [NubeService] Validando datos antes de enviar...');
      
      // Validar que los datos sean serializables
      try {
        jsonEncode(requestData);
      } catch (e) {
        print('❌ [NubeService] Error al serializar datos: $e');
        return {'success': false, 'error': 'Error al preparar los datos para enviar: $e'};
      }

      print('📨 [NubeService] Preparando petición...');
      
      // Configurar headers con manejo de errores
      final headers = {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
        'X-User-ID': userId,
        'X-App-Version': '1.0.0',
        'X-Platform': 'mobile',
      };
      
      // Log seguro (sin exponer datos sensibles)
      print('   - Headers: ${{
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer ***${token.length > 4 ? token.substring(token.length - 4) : '...'}',
        'X-User-ID': userId,
        'X-App-Version': '1.0.0',
        'X-Platform': 'mobile',
      }}');
      
      // Log resumido del body
      print('   - Body resumido: ${{
        'userId': userId,
        'clientes': clientes.length,
        'productos': productos.length,
        'movimientos': movimientos.length,
        'pedidos': pedidos.length,
        'deleted': deleted.map((k, v) => MapEntry(k, v is List ? v.length : v)),
      }}');

      // Configurar timeout con reintentos
      const maxRetries = 3;
      int attempt = 0;
      http.Response? response;
      
      while (attempt < maxRetries) {
        attempt++;
        print('🔄 [NubeService] Intento $attempt de $maxRetries...');
        
        try {
          response = await http.post(
            url,
            headers: headers,
            body: jsonEncode(requestData),
          ).timeout(const Duration(seconds: 30));
          break; // Salir del bucle si la petición tiene éxito
        } on TimeoutException {
          if (attempt == maxRetries) rethrow;
          print('⏱️ [NubeService] Timeout en intento $attempt, reintentando...');
          await Future.delayed(Duration(seconds: attempt * 2)); // Espera exponencial
        } catch (e) {
          if (attempt == maxRetries) rethrow;
          print('⚠️ [NubeService] Error en intento $attempt: $e');
          await Future.delayed(Duration(seconds: attempt));
        }
      }
      
      if (response == null) {
        throw Exception('No se pudo completar la petición después de $maxRetries intentos');
      }

      print('📥 [NubeService] Respuesta recibida:');
      print('   - Status: ${response.statusCode}');
      print('   - Headers: ${response.headers}');
      
      // Validar y decodificar la respuesta
      dynamic responseBody;
      try {
        responseBody = jsonDecode(utf8.decode(response.bodyBytes));
        print('   - Body: ${responseBody.toString().length > 500 ? '${responseBody.toString().substring(0, 500)}...' : responseBody}');
      } catch (e) {
        print('⚠️ [NubeService] No se pudo decodificar la respuesta como JSON: ${response.body}');
        responseBody = {'raw': response.body};
      }
      
      // Manejar códigos de estado HTTP
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Éxito
        print('✅ [NubeService] Sincronización exitosa (${response.statusCode})');
        return {
          'success': true, 
          'data': responseBody,
          'statusCode': response.statusCode,
        };
      } else if (response.statusCode == 401) {
        // No autorizado
        final errorMsg = responseBody['error']?.toString() ?? 'No autorizado';
        print('🔐 [NubeService] Error de autenticación:');
        print('   - Código: 401');
        print('   - Mensaje: $errorMsg');
        
        return {
          'success': false, 
          'error': 'Tu sesión ha expirado. Por favor, inicia sesión de nuevo.',
          'statusCode': 401,
          'requiresLogin': true,
        };
      } else if (response.statusCode >= 500) {
        // Error del servidor
        final errorMsg = responseBody['error']?.toString() ?? 'Error en el servidor';
        print('🔥 [NubeService] Error del servidor:');
        print('   - Código: ${response.statusCode}');
        print('   - Mensaje: $errorMsg');
        
        return {
          'success': false, 
          'error': 'Error en el servidor. Por favor, inténtalo de nuevo más tarde.',
          'statusCode': response.statusCode,
          'isServerError': true,
        };
      } else {
        // Otros errores del cliente
        final errorMsg = responseBody['error']?.toString() ?? 'Error desconocido';
        print('❌ [NubeService] Error en la solicitud:');
        print('   - Código: ${response.statusCode}');
        print('   - Mensaje: $errorMsg');
        
        return {
          'success': false, 
          'error': errorMsg,
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
      return {'success': false, 'error': 'Error al sincronizar: ${e.toString()}'};
    }
  }

  // Función para realizar la petición HTTP en un aislado separado
  static Future<http.Response> _fetchDataInIsolate(Map<String, dynamic> params) async {
    final Uri url = params['url'];
    final Map<String, String> headers = Map<String, String>.from(params['headers']);
    
    final client = http.Client();
    try {
      final response = await client.get(url, headers: headers);
      
      // Asegurarse de que los bytes se decodifiquen correctamente
      if (response.bodyBytes != null && response.bodyBytes.isNotEmpty) {
        try {
          // Decodificar y volver a codificar para asegurar UTF-8 válido
          final body = utf8.decode(
            response.bodyBytes,
            allowMalformed: false,
          );
          
          return http.Response.bytes(
            utf8.encode(body),
            response.statusCode,
            request: response.request,
            headers: response.headers,
            isRedirect: response.isRedirect,
            persistentConnection: response.persistentConnection,
            reasonPhrase: response.reasonPhrase,
          );
        } catch (e) {
          print('⚠️ [DEBUG] Error al decodificar la respuesta: $e');
          // Si falla, devolver la respuesta original
        }
      }
      
      return response;
    } catch (e) {
      print('❌ [DEBUG] Error en _fetchDataInIsolate: $e');
      rethrow;
    } finally {
      client.close();
    }
  }
  
  // Función auxiliar para limpiar cadenas JSON
  static String _cleanJsonString(String input) {
    if (input.isEmpty) return input;
    
    try {
      // Primero intentar decodificar/recodificar para normalizar
      final bytes = utf8.encode(input);
      String cleaned = utf8.decode(bytes, allowMalformed: false);
      
      // Reemplazar caracteres de control y BOM
      cleaned = cleaned.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\uFEFF]'), '');
      
      // Reemplazar caracteres problemáticos comunes
      cleaned = cleaned
          .replaceAll('Ã¡', 'á')
          .replaceAll('Ã©', 'é')
          .replaceAll('Ã-', 'í')
          .replaceAll('Ã³', 'ó')
          .replaceAll('Ãº', 'ú')
          .replaceAll('Ã±', 'ñ')
          .replaceAll('Ã', 'í') // Para casos como 'Ã' que deberían ser 'í'
          .replaceAll('Â', ''); // Caracteres adicionales que pueden aparecer
      
      return cleaned;
    } catch (e) {
      print('⚠️ [DEBUG] Error al limpiar cadena: $e');
      // Si falla, devolver la entrada original sin caracteres de control
      return input.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F\uFEFF]'), '');
    }
  }

  /// ⬇️ Descarga datos de la nube (clientes, productos y movimientos)
  static Future<Map<String, dynamic>> descargarDesdeNube({
    required String userId,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/api/sync?userId=$userId');
    print('⬇️ [DEBUG] Iniciando descarga para usuario $userId');
    print('🌐 [DEBUG] URL: $url');

    try {
      print('🔑 [DEBUG] Token de autenticación: ${token.isNotEmpty ? '***${token.substring(token.length - 4)}' : 'vacío'}' );
      
      final stopwatch = Stopwatch()..start();
      print('⏱️ [DEBUG] Realizando petición HTTP en aislado...');
      
      // Realizar la petición en un aislado separado
      final response = await compute(
        _fetchDataInIsolate,
        {
          'url': url,
          'headers': {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer $token',
            'Accept': 'application/json; charset=utf-8',
            'Accept-Charset': 'utf-8',
          },
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          print('⏱️ [DEBUG] La petición ha excedido el tiempo de espera (30s)');
          throw TimeoutException('La conexión ha excedido el tiempo de espera');
        },
      );
      
      stopwatch.stop();
      print('⏱️ [DEBUG] Tiempo de respuesta: ${stopwatch.elapsedMilliseconds}ms');
      print('📥 [DEBUG] Respuesta del servidor (${response.statusCode})');
      print('📄 [DEBUG] Headers: ${response.headers}');
      
      // Decodificar el cuerpo como UTF-8
      final String responseBody = utf8.decode(response.bodyBytes);
      
      // Mostrar solo el inicio del body para no saturar los logs
      final bodyPreview = responseBody.length > 500 
          ? '${responseBody.substring(0, 500)}... (${responseBody.length} bytes en total)'
          : responseBody;
      print('📄 [DEBUG] Body: $bodyPreview');

      if (response.statusCode == 200) {
        try {
          print('🔄 [DEBUG] Procesando respuesta JSON...');
          final dynamic decodedBody = jsonDecode(responseBody);
          
          if (decodedBody is! Map<String, dynamic>) {
            throw const FormatException('Formato de respuesta inválido: se esperaba un objeto JSON');
          }
          
          print('✅ [DEBUG] Respuesta JSON válida');
          
          // Verificar si la respuesta tiene el formato esperado
          if (decodedBody['success'] != true) {
            final errorMsg = decodedBody['error']?.toString() ?? 'Error en la respuesta del servidor';
            print('❌ [DEBUG] Error en la respuesta: $errorMsg');
            return {
              'success': false,
              'statusCode': response.statusCode,
              'error': errorMsg,
              'details': decodedBody.toString(),
            };
          }
          
          final responseData = decodedBody['data'] as Map<String, dynamic>?;
          if (responseData == null) {
            throw const FormatException('Datos de respuesta faltantes en la respuesta del servidor');
          }
          
          // Función para limpiar cadenas en los datos
          T _cleanData<T>(T data) {
            if (data is Map) {
              return Map<String, dynamic>.fromEntries(
                (data as Map).entries.map((e) => 
                  MapEntry(e.key.toString(), _cleanData(e.value))
                )
              ) as T;
            } else if (data is List) {
              return (data as List).map((e) => _cleanData(e)).toList() as T;
            } else if (data is String) {
              return _cleanJsonString(data) as T;
            }
            return data;
          }
          
          // Limpiar los datos recibidos
          final cleanedData = _cleanData(responseData);
          
          // Asegurarse de que todos los campos esperados estén presentes
          final clientes = cleanedData['clientes'] is List ? cleanedData['clientes'] : [];
          final productos = cleanedData['productos'] is List ? cleanedData['productos'] : [];
          final movimientos = cleanedData['movimientos'] is List ? cleanedData['movimientos'] : [];
          
          print('✅ [DEBUG] Datos procesados correctamente:');
          print('  - Clientes: ${clientes.length}');
          print('  - Productos: ${productos.length}');
          print('  - Movimientos: ${movimientos.length}');
          
          if (clientes.isNotEmpty) print('    - Primer cliente: ${clientes.first}');
          if (productos.isNotEmpty) print('    - Primer producto: ${productos.first}');
          if (movimientos.isNotEmpty) print('    - Primer movimiento: ${movimientos.first}');
                
          return {
            'success': true,
            'statusCode': response.statusCode,
            'data': {
              'clientes': clientes,
              'productos': productos,
              'movimientos': movimientos,
            }
          };
        } catch (e, stackTrace) {
          print('❌ [DEBUG] Error al procesar la respuesta JSON:');
          print('  - Error: $e');
          print('  - Stack trace: $stackTrace');
          return {
            'success': false,
            'statusCode': response.statusCode,
            'error': 'Error al procesar la respuesta del servidor',
            'details': e.toString(),
          };
        }
      } else if (response.statusCode == 401) {
        // Token expirado o inválido
        String errorMsg = 'Sesión expirada o no autorizada';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['error'] ?? errorMsg;
        } catch (_) {}
        
        print('🔐 Error de autenticación (401): $errorMsg');
        return {
          'success': false,
          'error': 'Tu sesión ha expirado. Por favor, inicia sesión de nuevo.',
          'statusCode': 401,
          'requiresLogin': true,
        };
      } else {
        // Otros errores HTTP
        String errorMsg = 'Error desconocido';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['error']?.toString() ?? errorMsg;
        } catch (_) {}
        
        print('❌ Error al descargar (${response.statusCode}): $errorMsg');
        return {
          'success': false,
          'error': 'Error ${response.statusCode}: $errorMsg',
          'statusCode': response.statusCode,
        };
      }
    } on http.ClientException catch (e) {
      final error = 'No se pudo conectar al servidor. Verifica tu conexión a internet.';
      print('❌ Error de conexión: ${e.message}');
      return {
        'success': false, 
        'error': error,
        'connectionError': true,
      };
    } on TimeoutException {
      const error = 'El servidor está tardando demasiado en responder. Intenta nuevamente más tarde.';
      print('❌ Tiempo de espera agotado');
      return {
        'success': false, 
        'error': error,
        'timeout': true,
      };
    } catch (e, stackTrace) {
      final error = 'Error inesperado al descargar datos';
      print('❌ $error: $e\n$stackTrace');
      return {
        'success': false, 
        'error': '$error: ${e.toString()}',
        'unexpected': true,
      };
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
