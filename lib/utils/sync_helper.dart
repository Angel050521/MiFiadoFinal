import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/nube_service.dart';
import '../services/conexion_service.dart';
import '../db/database_helper.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/movimiento.dart';
import '../models/pedido.dart';
import '../models/gasto.dart';

class SyncHelper {
  static const _pendienteKey = 'pendiente_sincronizacion';
  static const _lastSyncKey = 'last_sync';

  static Future<bool> sincronizarPedido(Pedido pedido, String token) async {
    try {
      print('🔄 [SYNC] Iniciando sincronización de pedido ${pedido.id}');
      final nubeService = NubeService();
      
      // Obtener el userId del SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId == null || userId.isEmpty) {
        print('❌ [SYNC] No se pudo obtener el userId');
        return false;
      }
      
      final response = await nubeService.sincronizarDatos(
        userId: userId,
        token: token,
        pedidos: [pedido.toMap()],
      );
      
      if (response['success'] == true) {
        print('✅ [SYNC] Pedido ${pedido.id} sincronizado exitosamente');
        return true;
      } else {
        print('❌ [SYNC] Error al sincronizar pedido: ${response['message']}');
        return false;
      }
    } catch (e) {
      print('❌ [SYNC] Error al sincronizar pedido: $e');
      return false;
    }
  }

  static Future<bool> sincronizarGasto(Gasto gasto, String token) async {
    try {
      print('🔄 [SYNC] Iniciando sincronización de gasto ${gasto.id}');
      final nubeService = NubeService();
      
      // Obtener el userId del SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId == null || userId.isEmpty) {
        print('❌ [SYNC] No se pudo obtener el userId');
        return false;
      }
      
      final response = await nubeService.sincronizarDatos(
        userId: userId,
        token: token,
        gastos: [gasto.toMap()],
      );
      
      if (response['success'] == true) {
        print('✅ [SYNC] Gasto ${gasto.id} sincronizado exitosamente');
        return true;
      } else {
        print('❌ [SYNC] Error al sincronizar gasto: ${response['message']}');
        return false;
      }
    } catch (e) {
      print('❌ [SYNC] Error al sincronizar gasto: $e');
      return false;
    }
  }

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
    print('🔄 [DEBUG] Iniciando sincronización para usuario: $userId');
    print('🔑 [DEBUG] Token: ${token.length > 4 ? '***${token.substring(token.length - 4)}' : token.isNotEmpty ? '***[token_corto]' : 'VACÍO'} (${token.length} caracteres)');
    
    try {
      // Verificar si el token está vacío
      if (token.isEmpty) {
        print('❌ [ERROR] Token de autenticación vacío');
        throw Exception('No se pudo autenticar. Por favor, inicia sesión nuevamente.');
      }

      final db = DatabaseHelper.instance;
      final prefs = await SharedPreferences.getInstance();
      
      try {
        print('📊 [DEBUG] Obteniendo datos locales...');
        // Obtener datos locales
        final clientes = await db.getClientes();
        List<Map<String, dynamic>> productosJson = [];
        List<Map<String, dynamic>> movimientosJson = [];
        List<Map<String, dynamic>> pedidosJson = [];
        final gastos = await db.getGastos();
        List<Map<String, dynamic>> gastosJson = gastos.map((g) => g.toMap()).toList();

        print('📊 [DEBUG] Procesando ${clientes.length} clientes...');
        // Obtener todos los productos y movimientos
        for (final cliente in clientes) {
          try {
            // Obtener productos del cliente
            final productos = await db.getProductosPorCliente(int.parse(cliente.id!));
            for (final producto in productos) {
              productosJson.add(producto.toMap());
              final movimientos = await db.getMovimientosPorProducto(int.parse(producto.id!));
              movimientosJson.addAll(movimientos.map((m) => m.toMap()));
            }
          } catch (e) {
            print('⚠️ [WARN] Error al obtener datos del cliente ${cliente.id}: $e');
            // Continuar con los siguientes clientes
          }
        }
        
        // Obtener todos los pedidos (incluyendo aquellos sin cliente asociado)
        try {
          final todosLosPedidos = await db.getPedidos();
          print('📦 [SYNC] Obtenidos ${todosLosPedidos.length} pedidos para sincronizar');
          pedidosJson.addAll(todosLosPedidos.map((p) => p.toMap()));
        } catch (e) {
          print('⚠️ [WARN] Error al obtener todos los pedidos: $e');
        }

        // Obtener registros eliminados
        final registrosEliminados = await DatabaseHelper.instance.getRegistrosEliminados();
        
        // Inicializar contadores
        int clientesEliminados = 0;
        int productosEliminados = 0;
        int movimientosEliminados = 0;
        int pedidosEliminados = 0;
        
        // Mapa para agrupar registros eliminados por tipo
        final Map<String, List<Map<String, dynamic>>> eliminadosPorTipo = {
          'clientes': [],
          'productos': [],
          'movimientos': [],
          'pedidos': [],
        };
        
        // Agrupar registros eliminados por tipo
        for (var registro in registrosEliminados) {
          final tipo = registro['tipo'];
          if (tipo == 'cliente') {
            clientesEliminados++;
            eliminadosPorTipo['clientes']!.add(registro);
          } else if (tipo == 'producto') {
            productosEliminados++;
            eliminadosPorTipo['productos']!.add(registro);
          } else if (tipo == 'movimiento') {
            movimientosEliminados++;
            eliminadosPorTipo['movimientos']!.add(registro);
          } else if (tipo == 'pedido') {
            pedidosEliminados++;
            eliminadosPorTipo['pedidos']!.add(registro);
          }
        }
        
        // Limpiar registros eliminados que ya están sincronizados
        final ahora = DateTime.now();
        final haceUnaHora = ahora.subtract(const Duration(hours: 1));
        
        for (var tipo in eliminadosPorTipo.keys) {
          final registros = eliminadosPorTipo[tipo]!;
          final idsParaLimpiar = <String>[];
          
          for (var registro in registros) {
            final fechaEliminacion = DateTime.tryParse(registro['fecha_eliminacion'] ?? '');
            final estaSincronizado = registro['sincronizado'] == 1;
            
            // Limpiar si está sincronizado o tiene más de 1 hora
            if (estaSincronizado || 
                (fechaEliminacion != null && fechaEliminacion.isBefore(haceUnaHora))) {
              idsParaLimpiar.add(registro['id_original'].toString());
            }
          }
          
          if (idsParaLimpiar.isNotEmpty) {
            print('🧹 Limpiando ${idsParaLimpiar.length} registros de $tipo');
            await db.limpiarRegistrosEliminadosPorTipo(tipo, idsParaLimpiar);
          }
        }
        
        print('📤 [DEBUG] Datos listos para enviar:');
        print('   - Clientes: ${clientes.length}');
        print('   - Productos: ${productosJson.length}');
        print('   - Movimientos: ${movimientosJson.length}');
        print('   - Pedidos: ${pedidosJson.length}');
        print('   - Gastos: ${gastosJson.length}');
        print('   - Eliminados:');
        print('     - Clientes: $clientesEliminados');
        print('     - Productos: $productosEliminados');
        print('     - Movimientos: $movimientosEliminados');
        print('     - Pedidos: $pedidosEliminados');
        
        print('🌐 [DEBUG] Enviando datos a la nube...');
        print('   - Token length: ${token.length}');
        print('   - User ID length: ${userId.length}');

        // Formatear registros eliminados para la API
        final deletedMap = {
          'clientes': registrosEliminados
              .where((r) => r['tipo'] == 'cliente')
              .map((r) => r['id_original'])
              .toList(),
          'productos': registrosEliminados
              .where((r) => r['tipo'] == 'producto')
              .map((r) => r['id_original'])
              .toList(),
          'movimientos': registrosEliminados
              .where((r) => r['tipo'] == 'movimiento')
              .map((r) => r['id_original'])
              .toList(),
          'pedidos': registrosEliminados
              .where((r) => r['tipo'] == 'pedido')
              .map((r) => r['id_original'])
              .toList(),
        };

        // Enviar datos a la nube en bloques más pequeños para evitar timeouts
        final response = await _enviarDatosEnBloques(
          userId: userId,
          token: token,
          clientes: clientes,
          productos: productosJson,
          movimientos: movimientosJson,
          pedidos: pedidosJson,
          gastos: gastosJson,
          deleted: deletedMap,
        );
        
        // Si la sincronización fue exitosa, limpiar registros eliminados
        if (response['success'] == true) {
          // Marcar registros como sincronizados en lugar de eliminarlos inmediatamente
          // La limpieza real se hará en el próximo ciclo de sincronización
          await DatabaseHelper.instance.marcarRegistrosEliminadosComoSincronizados();
        }

        print('📥 [DEBUG] Respuesta del servidor: ${response.toString()}');

        // Procesar respuesta
        if (response['success'] == true) {
          final ahora = DateTime.now();
          final fechaFormateada = '${ahora.day}/${ahora.month}/${ahora.year} ${ahora.hour}:${ahora.minute.toString().padLeft(2, '0')}';
          
          // Actualizar estado de sincronización
          await prefs.setBool(_pendienteKey, false);
          await prefs.setString(_lastSyncKey, ahora.toIso8601String());
          
          print('✅ [SUCCESS] Sincronización exitosa a las $fechaFormateada');
          return;
        } else {
          final error = response['error']?.toString() ?? 'Error desconocido';
          final statusCode = response['statusCode']?.toString() ?? 'N/A';
          
          print('❌ [ERROR] Error en sincronización:');
          print('   - Código: $statusCode');
          print('   - Mensaje: $error');
          
          // Manejar errores específicos
          if (statusCode == '401' || error.toString().toLowerCase().contains('no autorizado')) {
            print('🔒 [AUTH] Token inválido o expirado');
            // Limpiar credenciales
            await prefs.remove('token');
            await prefs.remove('userId');
            throw Exception('Tu sesión ha expirado. Por favor, inicia sesión nuevamente.');
          }
          
          throw Exception('Error al sincronizar: $error');
        }
      } catch (e) {
        print('❌ Error al procesar la sincronización: $e');
        // Volver a lanzar el error para manejarlo en el llamador
        rethrow;
      }
    } catch (e) {
      print('❌ Error en SyncHelper.sincronizar: $e');
      rethrow;
    }
  }

  static Future<void> sincronizarSiConectado({required String userId, required String token}) async {
    final conectado = await ConexionService.hayConexion();
    if (!conectado) return;
    
    try {
      await sincronizar(userId, token);
    } catch (e) {
      print('❌ Error en sincronizarSiConectado: $e');
      rethrow;
    }
  }

  /// Envía los datos a la nube en bloques más pequeños para evitar timeouts
  static Future<Map<String, dynamic>> _enviarDatosEnBloques({
    required String userId,
    required String token,
    required List<Cliente> clientes,
    required List<Map<String, dynamic>> productos,
    required List<Map<String, dynamic>> movimientos,
    required Map<String, dynamic> deleted,
    required List<Map<String, dynamic>> pedidos,
    required List<Map<String, dynamic>> gastos,
  }) async {
    try {
      // Tamaño de lote para cada tipo de dato
      const batchSize = 20;
      
      // Enviar clientes en lotes
      for (var i = 0; i < clientes.length; i += batchSize) {
        final batch = clientes.sublist(
          i,
          i + batchSize > clientes.length ? clientes.length : i + batchSize,
        );
        
        print('📤 Enviando lote de clientes ${i ~/ batchSize + 1} (${batch.length} registros)');
        
        final response = await NubeService.sincronizarConNube(
          userId: userId,
          token: token,
          clientes: batch.map((c) => c.toMap()).toList(),
          productos: [],
          movimientos: [],
          pedidos: [],
          deleted: {},
        );
        
        if (response['success'] != true) {
          return response; // Retornar en caso de error
        }
        
        // Pequeña pausa entre lotes
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Enviar productos en lotes
      for (var i = 0; i < productos.length; i += batchSize) {
        final batch = productos.sublist(
          i,
          i + batchSize > productos.length ? productos.length : i + batchSize,
        );
        
        print('📤 Enviando lote de productos ${i ~/ batchSize + 1} (${batch.length} registros)');
        
        final response = await NubeService.sincronizarConNube(
          userId: userId,
          token: token,
          clientes: [],
          productos: batch,
          movimientos: [],
          pedidos: [],
          deleted: {},
        );
        
        if (response['success'] != true) {
          return response; // Retornar en caso de error
        }
        
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Enviar movimientos en lotes
      for (var i = 0; i < movimientos.length; i += batchSize) {
        final batch = movimientos.sublist(
          i,
          i + batchSize > movimientos.length ? movimientos.length : i + batchSize,
        );
        
        print('📤 Enviando lote de movimientos ${i ~/ batchSize + 1} (${batch.length} registros)');
        
        final response = await NubeService.sincronizarConNube(
          userId: userId,
          token: token,
          clientes: [],
          productos: [],
          movimientos: batch,
          pedidos: [],
          deleted: {},
        );
        
        if (response['success'] != true) {
          return response; // Retornar en caso de error
        }
        
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Enviar pedidos en lotes
      for (var i = 0; i < pedidos.length; i += batchSize) {
        final batch = pedidos.sublist(
          i,
          i + batchSize > pedidos.length ? pedidos.length : i + batchSize,
        );
        
        print('📦 Enviando lote de pedidos ${i ~/ batchSize + 1} (${batch.length} registros)');
        
        final response = await NubeService.sincronizarConNube(
          userId: userId,
          token: token,
          clientes: [],
          productos: [],
          movimientos: [],
          pedidos: batch,
          deleted: {},
        );
        
        if (response['success'] != true) {
          return response; // Retornar en caso de error
        }
        
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Enviar gastos en lotes
      for (var i = 0; i < gastos.length; i += batchSize) {
        final batch = gastos.sublist(
          i,
          i + batchSize > gastos.length ? gastos.length : i + batchSize,
        );
        print('💸 Enviando lote de gastos [33m[1m${i ~/ batchSize + 1}[0m ([32m${batch.length}[0m registros)');
        final response = await NubeService.sincronizarConNube(
          userId: userId,
          token: token,
          clientes: [],
          productos: [],
          movimientos: [],
          pedidos: [],
          gastos: batch,
          deleted: {},
        );
        if (response['success'] != true) {
          return response; // Retornar en caso de error
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      // Finalmente, enviar las eliminaciones
      if (deleted.isNotEmpty) {
        print('🗑️ Enviando registros eliminados');
        
        final response = await NubeService.sincronizarConNube(
          userId: userId,
          token: token,
          clientes: [],
          productos: [],
          movimientos: [],
          pedidos: [],
          deleted: deleted,
        );
        
        if (response['success'] != true) {
          return response; // Retornar en caso de error
        }
      }
      
      return {'success': true};
    } catch (e, stackTrace) {
      print('❌ Error en _enviarDatosEnBloques: $e\n$stackTrace');
      return {'success': false, 'error': 'Error al enviar datos en bloques: $e'};
    }
  }

  static void _mostrarError(BuildContext context, String mensaje) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Cerrar',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  static Future<bool> restaurarDesdeNube(BuildContext context) async {
    print('🔄 [DEBUG] Iniciando restaurarDesdeNube');
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      var token = prefs.getString('token') ?? '';
      
      if (userId.isEmpty || token.isEmpty) {
        final errorMsg = 'No se pudo restaurar: userId o token vacíos';
        print('❌ [DEBUG] $errorMsg');
        _mostrarError(context, errorMsg);
        return false;
      }

      print('🔄 [DEBUG] Iniciando restauración desde la nube para usuario: $userId');
      print('🔑 [DEBUG] Token: ${token.substring(0, 10)}...');
      
      // Mostrar diálogo de carga
      print('🔄 [DEBUG] Mostrando diálogo de carga...');
      bool? confirmado;
      
      try {
        // Usar un completer para manejar el cierre del diálogo
        final completer = Completer<bool>();
        
        // Mostrar el diálogo sin esperar (usando postFrameCallback)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return WillPopScope(
                  onWillPop: () async => false, // Evitar que se cierre al presionar atrás
                  child: AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Restaurando datos desde la nube...'),
                      ],
                    ),
                  ),
                );
              },
            ).then((value) {
              if (!completer.isCompleted) {
                completer.complete(value);
              }
            });
          } catch (e) {
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        });
        
        // Esperar un momento para asegurar que el diálogo se muestre
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Completar con true después de asegurarnos de que el diálogo se mostró
        if (!completer.isCompleted) {
          completer.complete(true);
        }
        
        confirmado = await completer.future;
        print('🔄 [DEBUG] Diálogo cerrado con resultado: $confirmado');
      } catch (e) {
        print('❌ [DEBUG] Error mostrando diálogo: $e');
        // Continuar aunque falle el diálogo
        confirmado = true;
      }

      if (confirmado == false) {
        print('ℹ️ [DEBUG] Usuario canceló la operación');
        return false;
      }

      NavigatorState? navigator;
      if (context.mounted) {
        navigator = Navigator.of(context, rootNavigator: true);
      }
      
      Map<String, dynamic> response;
      try {
        response = await NubeService.descargarDesdeNube(userId: userId, token: token);
        print('🔄 [DEBUG] Respuesta recibida de descargarDesdeNube');
      } finally {
        // Cerrar diálogo de carga si el contexto sigue montado
        if (context.mounted && navigator != null && navigator!.canPop()) {
          navigator!.pop();
        }
      }
      
      if (response == null) {
        final errorMsg = 'La respuesta del servidor es nula';
        print('❌ [DEBUG] $errorMsg');
        _mostrarError(context, errorMsg);
        return false;
      }
      
      print('📥 [DEBUG] Estado de la respuesta: ${response['success']}');
      print('📊 [DEBUG] Código de estado: ${response['statusCode']}');
      
      if (!response['success']) {
        final statusCode = response['statusCode'];
        final errorMsg = response['error']?.toString() ?? 'Error desconocido';
        final details = response['details']?.toString() ?? 'Sin detalles adicionales';
        
        print('❌ [DEBUG] Error en la respuesta:');
        print('  - Código: $statusCode');
        print('  - Mensaje: $errorMsg');
        print('  - Detalles: $details');
        
        if (statusCode == 401) {
          final authError = 'Tu sesión ha expirado. Por favor, inicia sesión nuevamente.';
          print('🔒 [DEBUG] Error de autenticación, cerrando sesión...');
          await prefs.remove('token');
          await prefs.remove('userId');
          if (context.mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
          }
        } else {
          _mostrarError(context, 'Error al descargar datos: $errorMsg');
        }
        return false;
      }

      final data = response['data'];
      if (data == null) {
        final errorMsg = 'Los datos de sincronización son nulos';
        print('❌ [DEBUG] $errorMsg');
        _mostrarError(context, 'Datos de sincronización inválidos');
        return false;
      }
      
      print('📦 [DEBUG] Datos recibidos:');
      print('  - Clientes: ${data['clientes']?.length ?? 0}');
      print('  - Productos: ${data['productos']?.length ?? 0}');
      print('  - Movimientos: ${data['movimientos']?.length ?? 0}');

      final db = DatabaseHelper.instance;
      await db.database;

      // Verificar si hay datos para restaurar
      bool hayDatos = false;
      int clientesRestaurados = 0;
      int productosRestaurados = 0;
      int movimientosRestaurados = 0;

      // Procesar clientes
      if (data['clientes'] is List) {
        final clientes = data['clientes'] as List;
        hayDatos = hayDatos || clientes.isNotEmpty;
        
        for (final clienteData in clientes) {
          try {
            final cliente = Cliente.fromMap(clienteData);
            await db.insertCliente(cliente);
            clientesRestaurados++;
          } catch (e) {
            print('⚠️ Error al insertar cliente: $e');
            print('Datos del cliente fallido: $clienteData');
          }
        }
      }

      // Procesar productos
      if (data['productos'] is List) {
        final productos = data['productos'] as List;
        hayDatos = hayDatos || productos.isNotEmpty;
        
        for (final productoData in productos) {
          try {
            final producto = Producto.fromMap(productoData);
            await db.insertProducto(producto);
            productosRestaurados++;
          } catch (e) {
            print('⚠️ Error al insertar producto: $e');
            print('Datos del producto fallido: $productoData');
          }
        }
      }

      // Procesar movimientos
      if (data['movimientos'] is List) {
        final movimientos = data['movimientos'] as List;
        hayDatos = hayDatos || movimientos.isNotEmpty;
        
        for (final movimientoData in movimientos) {
          try {
            final movimiento = Movimiento.fromMap(movimientoData);
            await db.insertMovimiento(movimiento);
            movimientosRestaurados++;
          } catch (e) {
            print('⚠️ Error al insertar movimiento: $e');
            print('Datos del movimiento fallido: $movimientoData');
          }
        }
      }

      // Procesar pedidos
      if (data['pedidos'] is List) {
        final pedidosRemotos = data['pedidos'] as List;
        hayDatos = hayDatos || pedidosRemotos.isNotEmpty;
        
        for (var pedidoData in pedidosRemotos) {
          final idPedido = pedidoData['id']?.toString();
          final eliminados = await db.query(
            'registros_eliminados',
            where: 'tipo = ? AND id_original = ?',
            whereArgs: ['pedido', idPedido],
          );
          if (eliminados.isNotEmpty) {
            print('⛔ Pedido $idPedido está marcado como eliminado, no se restaura.');
            continue;
          }
          try {
            final pedido = Pedido.fromMap(pedidoData);
            await db.insertOrUpdatePedido(pedido);
          } catch (e) {
            print('❌ Error al guardar pedido localmente: $e');
          }
        }
      }

      if (!hayDatos) {
        if (context.mounted) {
          _mostrarError(context, 'No hay datos para restaurar en la nube');
        }
        return false;
      }

      // Actualizar última sincronización
      final ahora = DateTime.now();
      final fechaFormateada = '${ahora.day}/${ahora.month}/${ahora.year} ${ahora.hour}:${ahora.minute.toString().padLeft(2, '0')}';
      await prefs.setString(_lastSyncKey, fechaFormateada);
      await prefs.setBool(_pendienteKey, false);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Datos restaurados correctamente\n'
              'Clientes: $clientesRestaurados, '
              'Productos: $productosRestaurados, '
              'Movimientos: $movimientosRestaurados',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }

      print('✅ Restauración completada - '
            'Clientes: $clientesRestaurados, '
            'Productos: $productosRestaurados, '
            'Movimientos: $movimientosRestaurados');

      return true;
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Cerrar diálogo de carga si está abierto
        _mostrarError(context, 'Error al restaurar datos: $e');
      }
      print('❌ Error en restaurarDesdeNube: $e');
      return false;
    }
  }

  static Future<void> intentarSincronizar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conectado = await ConexionService.hayConexion();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');
      final plan = prefs.getString('plan');

      print('🔍 Estado de sincronización:');
      print('   - Conectado: $conectado');
      print('   - User ID: ${userId != null && userId.length >= 3 ? '***${userId.substring(0, 3)}' : userId ?? 'null'}');
      print('   - Token: ${token != null && token.length >= 4 ? '***${token.substring(token.length - 4)}' : token != null ? '***[token_corto]' : 'null'}');
      print('   - Plan: $plan');

      // Verificar si el plan es válido para sincronización
      // Planes válidos: nube100mxn, premium150mxn
      // Planes no válidos: basico, free, o cualquier otro
      final esPlanValido = plan != null && 
          (plan == 'nube100mxn' || plan == 'premium150mxn');
      
      print('   - Plan válido para sincronización: $esPlanValido');
      print('   - Plan actual: $plan');

      if (conectado && userId != null && token != null && esPlanValido) {
        print('🔄 Iniciando sincronización...');
        await sincronizar(userId, token);
        print('✅ Sincronización completada');
      } else if (!esPlanValido) {
        print('⚠️ El plan actual no permite sincronización: $plan');
      }
    } catch (e) {
      print('❌ Error en intentarSincronizar: $e');
      rethrow;
    }
  }
}
