import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/nube_service.dart';
import '../services/conexion_service.dart';
import '../db/database_helper.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/movimiento.dart';

class SyncHelper {
  static const _pendienteKey = 'pendiente_sincronizacion';
  static const _lastSyncKey = 'last_sync';

  static Future<void> marcarPendiente() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendienteKey, true);
  }

  static Future<bool> hayPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_pendienteKey) ?? false;
  }

  static Future<String?> obtenerUltimaSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncKey);
  }

  static Future<void> sincronizar(String userId, String token) async {
    final db = DatabaseHelper();
    final prefs = await SharedPreferences.getInstance();
    final clientes = await db.getClientes();

    List<Map<String, dynamic>> productosJson = [];
    List<Map<String, dynamic>> movimientosJson = [];

    for (final cliente in clientes) {
      final productos = await db.getProductosPorCliente(cliente.id!);
      for (final producto in productos) {
        productosJson.add(producto.toMap());
        final movimientos = await db.getMovimientosPorProducto(producto.id!);
        movimientosJson.addAll(movimientos.map((m) => m.toMap()));
      }
    }

    await NubeService.sincronizarConNube(
      userId: userId,
      token: token,
      clientes: clientes.map((c) => c.toMap()).toList(),
      productos: productosJson,
      movimientos: movimientosJson,
    );

    await prefs.setBool(_pendienteKey, false);
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
  }

  static Future<void> sincronizarSiConectado({required String userId, required String token}) async {
    final conectado = await ConexionService.hayConexion();
    if (!conectado) return;
    await sincronizar(userId, token);
  }

  static Future<void> restaurarDesdeNube(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    final token = prefs.getString('token') ?? '';
    if (userId.isEmpty || token.isEmpty) return;

    final data = await NubeService.descargarDesdeNube(userId: userId, token: token);
    if (data == null) return;

    final db = DatabaseHelper();
    final clientes = data['clientes'] as List;
    final productos = data['productos'] as List;
    final movimientos = data['movimientos'] as List;

    final dbInstance = await db.database;
    await dbInstance.delete('clientes');
    await dbInstance.delete('productos');
    await dbInstance.delete('movimientos');

    for (final c in clientes) {
      await db.insertCliente(Cliente.fromMap(c));
    }
    for (final p in productos) {
      await db.insertProducto(Producto.fromMap(p));
    }
    for (final m in movimientos) {
      await db.insertMovimiento(Movimiento.fromMap(m));
    }

    await prefs.setBool(_pendienteKey, false);
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Restauración completada"),
        backgroundColor: Colors.green,
      ),
    );
  }

  static Future<void> intentarSincronizar() async {
    final prefs = await SharedPreferences.getInstance();
    final conectado = await ConexionService.hayConexion();
    final userId = prefs.getString('userId');
    final token = prefs.getString('token');
    final plan = prefs.getString('plan');

    if (conectado && userId != null && token != null && (plan == 'premium' || plan == 'basico')) {
      await sincronizar(userId, token);
    }
  }
}
