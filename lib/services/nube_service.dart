import 'dart:convert';
import 'package:http/http.dart' as http;

class NubeService {
  static const String baseUrl = 'https://fiadosync.angel050521.workers.dev';

  /// 🔄 Actualiza el plan de un usuario en la nube
  static Future<bool> actualizarPlan({
    required String userId,
    required String token,
    required String plan,
  }) async {
    final url = Uri.parse('$baseUrl/actualizar_plan');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': userId,
          'plan': plan,
        }),
      );

      if (response.statusCode == 200) {
        print('✅ Plan actualizado a $plan');
        return true;
      } else {
        print('❌ Error al actualizar plan: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error en actualizarPlan: $e');
      return false;
    }
  }

  /// 🔄 Envía los datos a la nube (clientes, productos y movimientos)
  static Future<void> sincronizarConNube({
    required String userId,
    required String token,
    required List<Map<String, dynamic>> clientes,
    required List<Map<String, dynamic>> productos,
    required List<Map<String, dynamic>> movimientos,
  }) async {
    final url = Uri.parse('$baseUrl/upload');

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
    );

    if (response.statusCode == 200) {
      print('✅ Sincronización exitosa: ${response.body}');
    } else {
      print('❌ Error al sincronizar (${response.statusCode}): ${response.body}');
    }
  }

  /// ⬇️ Descarga datos de la nube (clientes, productos y movimientos)
  static Future<Map<String, dynamic>?> descargarDesdeNube({
    required String userId,
    required String token,
  }) async {
    final url = Uri.parse('$baseUrl/download?userId=$userId');

    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return {
        'clientes': data['clientes'] ?? [],
        'productos': data['productos'] ?? [],
        'movimientos': data['movimientos'] ?? [],
      };
    } else {
      print('❌ Error al descargar (${response.statusCode}): ${response.body}');
      return null;
    }
  }

  /// ✅ Verifica si el deviceId actual está autorizado o si se requiere migración
  static Future<bool> validarODeseaMigrar({
    required String userId,
    required String token,
    required String deviceId,
  }) async {
    final url = Uri.parse('$baseUrl/validar_device');

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
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['permitido'] == true;
    } else {
      print("❌ Error al validar deviceId: ${response.body}");
      return false;
    }
  }

  /// 🛠️ Actualiza el deviceId en la nube (si el usuario desea migrar)
  static Future<void> actualizarDevice({
    required String userId,
    required String token,
    required String deviceId,
  }) async {
    final url = Uri.parse('$baseUrl/actualizar_device');

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
    );

    if (response.statusCode == 200) {
      print('✅ DeviceId actualizado en la nube');
    } else {
      print('❌ Error al actualizar deviceId: ${response.body}');
    }
  }
}
