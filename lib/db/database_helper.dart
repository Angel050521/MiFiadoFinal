import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/Cliente.dart';
import '../models/Producto.dart';
import '../models/Movimiento.dart';
import '../models/pedido.dart';
import '../models/gasto.dart';

// SINGLETON para acceso a la base local
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();

  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('fiado.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5, // Incremented version to add soft delete support
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 [MIGRACION] Actualizando base de datos de la versión $oldVersion a $newVersion');
    
    if (oldVersion < 4) {
      // Migración para la tabla de movimientos
      await db.execute('''
        CREATE TABLE IF NOT EXISTS movimientos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          productoId INTEGER,
          tipo TEXT,
          cantidad REAL,
          fecha TEXT,
          descripcion TEXT,
          FOREIGN KEY (productoId) REFERENCES productos(id)
        );
      ''');
    }
    
    if (oldVersion < 5) {
      // Migración para soporte de borrado lógico
      try {
        // Agregar columnas a la tabla clientes si no existen
        try {
          await db.execute('ALTER TABLE clientes ADD COLUMN eliminado INTEGER DEFAULT 0');
          print('✅ [MIGRACION] Columna "eliminado" agregada a la tabla clientes');
        } catch (e) {
          if (e.toString().contains('duplicate column')) {
            print('ℹ️ [MIGRACION] La columna "eliminado" ya existe en clientes');
          } else {
            rethrow;
          }
        }
        
        try {
          await db.execute('ALTER TABLE clientes ADD COLUMN sincronizado INTEGER DEFAULT 0');
          print('✅ [MIGRACION] Columna "sincronizado" agregada a la tabla clientes');
        } catch (e) {
          if (e.toString().contains('duplicate column')) {
            print('ℹ️ [MIGRACION] La columna "sincronizado" ya existe en clientes');
          } else {
            rethrow;
          }
        }
        
        // Crear tabla de registros_eliminados si no existe
        await db.execute('''
          CREATE TABLE IF NOT EXISTS registros_eliminados (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT NOT NULL,
            id_original TEXT NOT NULL,
            fecha_eliminacion TEXT DEFAULT CURRENT_TIMESTAMP,
            sincronizado INTEGER DEFAULT 0
          );
        ''');
        
        print('✅ [MIGRACION] Tabla registros_eliminados creada o ya existente');
        
      } catch (e, stackTrace) {
        print('❌ [ERROR] Error en migración a versión 5: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }
    
    print('✅ [MIGRACION] Base de datos actualizada exitosamente a la versión $newVersion');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT,
        email TEXT UNIQUE,
        password TEXT,
        plan TEXT,
        token TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT,
        telefono TEXT,
        eliminado INTEGER DEFAULT 0,
        sincronizado INTEGER DEFAULT 0
      );
    ''');
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS registros_eliminados (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT NOT NULL,
        id_original TEXT NOT NULL,
        fecha_eliminacion TEXT DEFAULT CURRENT_TIMESTAMP,
        sincronizado INTEGER DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT,
        clienteId INTEGER,
        deuda REAL,
        FOREIGN KEY (clienteId) REFERENCES clientes(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE movimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productoId INTEGER,
        tipo TEXT,
        cantidad REAL,
        fecha TEXT,
        descripcion TEXT,
        FOREIGN KEY (productoId) REFERENCES productos(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS pedidos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER,
        titulo TEXT NOT NULL,
        descripcion TEXT,
        fecha_entrega TEXT,
        precio REAL,
        hecho INTEGER DEFAULT 0,
        fecha_hecho TEXT,
        cliente_nombre TEXT,
        cliente_telefono TEXT,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE SET NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        descripcion TEXT,
        cantidad REAL,
        fecha TEXT
      );
    ''');
  }

  // --------- MÉTODOS USUARIOS ---------
  Future<int> insertUsuario(String nombre, String email, String password) async {
    final db = await instance.database;
    return await db.insert('usuarios', {
      'nombre': nombre,
      'email': email,
      'password': password,
      'plan': '',
      'token': '',
    });
  }

  Future<Map<String, dynamic>?> loginUsuario(String email, String password) async {
    final db = await instance.database;
    final result = await db.query(
      'usuarios',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getUsuarioByEmail(String email) async {
    final db = await instance.database;
    final result = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: [email],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> updateUsuario(int id, Map<String, dynamic> values) async {
    final db = await instance.database;
    return await db.update('usuarios', values, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteUsuario(int id) async {
    final db = await instance.database;
    return await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllUsuarios() async {
    final db = await instance.database;
    return await db.query('usuarios');
  }

  // --------- MÉTODOS CLIENTES ---------
  Future<int> insertCliente(Cliente cliente) async {
    try {
      print('🔄 [DEBUG] Iniciando insertCliente');
      print('   - Nombre: ${cliente.nombre}');
      print('   - Teléfono: ${cliente.telefono}');
      
      final db = await instance.database;
      print('   - Base de datos obtenida');
      
      final map = cliente.toMap();
      print('   - Mapa del cliente: $map');
      
      final id = await db.insert('clientes', map);
      print('✅ [DEBUG] Cliente insertado con ID: $id');
      
      // Verificar que el cliente se haya guardado correctamente
      final clienteGuardado = await db.query(
        'clientes',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (clienteGuardado.isNotEmpty) {
        print('✅ [DEBUG] Cliente verificado en la base de datos: ${clienteGuardado.first}');
      } else {
        print('⚠️ [WARNING] No se pudo verificar el cliente en la base de datos');
      }
      
      return id;
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en insertCliente: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Cliente>> getClientes() async {
    try {
      print('🔄 [DEBUG] Iniciando getClientes');
      final db = await instance.database;
      print('   - Base de datos obtenida');
      
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='clientes'"
      );
      
      if (tables.isEmpty) {
        print('⚠️ [WARNING] La tabla clientes no existe');
        return [];
      }
      
      print('   - Tabla clientes encontrada');
      
      // Solo obtener clientes no eliminados
      final result = await db.query(
        'clientes',
        where: 'eliminado = ?',
        whereArgs: [0],
      );
      
      print('✅ [DEBUG] Clientes activos encontrados: ${result.length}');
      
      final clientes = result.map((json) {
        try {
          return Cliente.fromMap(json);
        } catch (e) {
          print('⚠️ [WARNING] Error al mapear cliente: $e');
          print('   - Datos del cliente: $json');
          return Cliente(nombre: 'Error', telefono: '');
        }
      }).toList();
      
      return clientes;
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en getClientes: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<int> updateCliente(Cliente cliente) async {
    final db = await instance.database;
    return await db.update('clientes', cliente.toMap(), where: 'id = ?', whereArgs: [cliente.id]);
  }

  Future<int> eliminarCliente(String id) async {
    try {
      print('🔄 [DEBUG] Iniciando eliminación de cliente ID: $id');
      final db = await instance.database;
      
      // Primero obtenemos el cliente para verificar que existe
      final cliente = await db.query(
        'clientes',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (cliente.isEmpty) {
        print('⚠️ [WARNING] No se encontró el cliente con ID: $id para eliminar');
        return 0;
      }
      
      // Insertar en la tabla de registros_eliminados
      await db.insert('registros_eliminados', {
        'tipo': 'cliente',
        'id_original': id,
        'sincronizado': 0,
      });
      
      // Marcar como eliminado en la tabla de clientes
      final result = await db.update(
        'clientes',
        {'eliminado': 1, 'sincronizado': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
      
      print('✅ [DEBUG] Cliente marcado como eliminado: $id');
      return result;
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en eliminarCliente: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  // --------- MÉTODOS PRODUCTOS ---------
  Future<int> insertProducto(Producto producto) async {
    final db = await instance.database;
    return await db.insert('productos', producto.toMap());
  }

  Future<List<Producto>> getProductosPorCliente(int clienteId) async {
    final db = await instance.database;
    final result = await db.query('productos', where: 'clienteId = ?', whereArgs: [clienteId]);
    return result.map((json) => Producto.fromMap(json)).toList();
  }

  Future<int> updateProducto(Producto producto) async {
    final db = await instance.database;
    return await db.update('productos', producto.toMap(), where: 'id = ?', whereArgs: [producto.id]);
  }

  Future<int> eliminarProducto(String id) async {
    final db = await instance.database;
    return await db.delete('productos', where: 'id = ?', whereArgs: [id]);
  }

  // --------- MÉTODOS MOVIMIENTOS ---------
  Future<int> insertMovimiento(Movimiento movimiento) async {
    try {
      final db = await instance.database;
      print('🔄 [DEBUG] Inserting movimiento:');
      print('   - productoId: ${movimiento.productoId}');
      print('   - tipo: ${movimiento.tipo}');
      print('   - monto: ${movimiento.monto}');
      print('   - fecha: ${movimiento.fecha}');
      print('   - descripcion: ${movimiento.descripcion}');
      
      final map = movimiento.toMap();
      print('📝 [DEBUG] Mapa a insertar: $map');
      
      final id = await db.insert('movimientos', map);
      print('✅ [DEBUG] Movimiento insertado con ID: $id');
      return id;
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error al insertar movimiento: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Movimiento>> getMovimientosPorProducto(int productoId) async {
    try {
      print('🔍 [DEBUG] Buscando movimientos para productoId: $productoId');
      final db = await instance.database;
      
      // Verificar si la tabla existe
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='movimientos'"
      );
      print('📊 [DEBUG] Tabla movimientos existe: ${tables.isNotEmpty}');
      
      // Obtener todos los movimientos para depuración
      final allMovimientos = await db.rawQuery('SELECT * FROM movimientos');
      print('📋 [DEBUG] Total de movimientos en la base de datos: ${allMovimientos.length}');
      
      // Obtener solo los del producto solicitado
      final result = await db.query(
        'movimientos', 
        where: 'productoId = ?', 
        whereArgs: [productoId],
        orderBy: 'fecha DESC',
      );
      
      print('✅ [DEBUG] Movimientos encontrados: ${result.length}');
      for (var mov in result) {
        print('   - Movimiento: $mov');
      }
      
      return result.map((json) => Movimiento.fromMap(json)).toList();
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error al obtener movimientos: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<int> eliminarMovimiento(String id) async {
    final db = await instance.database;
    return await db.delete('movimientos', where: 'id = ?', whereArgs: [id]);
  }

  // --------- MÉTODOS PEDIDOS ---------
  Future<int> insertPedido(Pedido pedido) async {
    final db = await instance.database;
    return await db.insert('pedidos', pedido.toMap());
  }

  Future<List<Pedido>> getPedidos() async {
    final db = await instance.database;
    final result = await db.query('pedidos');
    return result.map((json) => Pedido.fromMap(json)).toList();
  }

  Future<int> eliminarPedido(int id) async {
    final db = await instance.database;
    return await db.delete('pedidos', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updatePedido(Pedido pedido) async {
    final db = await instance.database;
    return await db.update('pedidos', pedido.toMap(), where: 'id = ?', whereArgs: [pedido.id]);
  }

  Future<List<Pedido>> getAllPedidos() async {
    final db = await instance.database;
    final result = await db.query('pedidos');
    return result.map((json) => Pedido.fromMap(json)).toList();
  }

  // --------- MÉTODOS GASTOS ---------
  Future<int> insertGasto(Gasto gasto) async {
    final db = await instance.database;
    return await db.insert('gastos', gasto.toMap());
  }

  Future<List<Gasto>> getGastos() async {
    final db = await instance.database;
    final result = await db.query('gastos');
    return result.map((json) => Gasto.fromMap(json)).toList();
  }

  Future<List<Gasto>> getGastosDelMes(DateTime fecha) async {
    final db = await instance.database;
    final firstDay = DateTime(fecha.year, fecha.month, 1).toIso8601String();
    final lastDay = DateTime(fecha.year, fecha.month + 1, 0, 23, 59, 59).toIso8601String();
    
    final result = await db.query(
      'gastos',
      where: 'fecha BETWEEN ? AND ?',
      whereArgs: [firstDay, lastDay],
    );
    return result.map((json) => Gasto.fromMap(json)).toList();
  }

  Future<int> eliminarGasto(int id) async {
    final db = await instance.database;
    return await db.delete('gastos', where: 'id = ?', whereArgs: [id]);
  }

  // --------- SINCRONIZACIÓN / AUXILIARES ---------
  
  /// Obtiene todos los registros eliminados que aún no se han sincronizado
  Future<List<Map<String, dynamic>>> getRegistrosEliminados() async {
    try {
      print('🔄 [DEBUG] Obteniendo registros eliminados');
      final db = await instance.database;
      
      // Verificar si la tabla existe
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='registros_eliminados'"
      );
      
      if (tables.isEmpty) {
        print('⚠️ [WARNING] La tabla registros_eliminados no existe');
        return [];
      }
      
      // Obtener registros no sincronizados
      final result = await db.query(
        'registros_eliminados',
        where: 'sincronizado = ?',
        whereArgs: [0],
      );
      
      print('✅ [DEBUG] Registros eliminados encontrados: ${result.length}');
      return result;
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en getRegistrosEliminados: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }
  
  /// Marca registros eliminados específicos como sincronizados
  Future<void> limpiarRegistrosEliminadosPorTipo(String tipo, List<String> ids) async {
    try {
      if (ids.isEmpty) return;
      
      final db = await instance.database;
      
      // Actualizar registros_eliminados marcándolos como sincronizados
      await db.update(
        'registros_eliminados',
        {'sincronizado': 1},
        where: 'tipo = ? AND id_original IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: [tipo, ...ids],
      );
      
      // Eliminar físicamente los registros de la tabla principal
      switch (tipo) {
        case 'cliente':
          await db.delete(
            'clientes',
            where: 'id IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids,
          );
          break;
        case 'producto':
          await db.delete(
            'productos',
            where: 'id IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids,
          );
          break;
        case 'movimiento':
          await db.delete(
            'movimientos',
            where: 'id IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids,
          );
          break;
        case 'pedido':
          await db.delete(
            'pedidos',
            where: 'id IN (${List.filled(ids.length, '?').join(',')})',
            whereArgs: ids,
          );
          break;
      }
      
      // Eliminar registros de la tabla de eliminados después de un tiempo
      await db.delete(
        'registros_eliminados',
        where: 'tipo = ? AND id_original IN (${List.filled(ids.length, '?').join(',')})',
        whereArgs: [tipo, ...ids],
      );
      
      print('✅ [DEBUG] Limpiados ${ids.length} registros de $tipo');
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en limpiarRegistrosEliminadosPorTipo: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Marca todos los registros eliminados como sincronizados
  Future<void> marcarRegistrosEliminadosComoSincronizados() async {
    try {
      final db = await instance.database;
      
      // Actualizar registros_eliminados marcándolos como sincronizados
      await db.update(
        'registros_eliminados',
        {'sincronizado': 1},
        where: 'sincronizado = ?',
        whereArgs: [0],
      );
      
      print('✅ [DEBUG] Marcados todos los registros eliminados como sincronizados');
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en marcarRegistrosEliminadosComoSincronizados: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Elimina físicamente los registros eliminados que ya han sido sincronizados
  /// o que tienen más de una hora de haber sido eliminados
  Future<void> limpiarRegistrosEliminados() async {
    try {
      print('🔄 [DEBUG] Limpiando registros eliminados sincronizados');
      final db = await instance.database;
      
      // Verificar si la tabla existe
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='registros_eliminados'"
      );
      
      if (tables.isEmpty) {
        print('ℹ️ [INFO] No hay tabla de registros_eliminados para limpiar');
        return;
      }
      
      // Actualizar registros_eliminados marcándolos como sincronizados
      final count = await db.update(
        'registros_eliminados',
        {'sincronizado': 1},
        where: 'sincronizado = ?',
        whereArgs: [0],
      );
      
      // Eliminar físicamente los registros que ya están marcados como sincronizados
      // Esto ayuda a mantener la base de datos limpia
      await db.delete(
        'registros_eliminados',
        where: 'sincronizado = ?',
        whereArgs: [1],
      );
      
      // También eliminamos físicamente los clientes marcados como eliminados
      // que ya han sido sincronizados con el servidor
      await db.delete(
        'clientes',
        where: 'eliminado = ? AND sincronizado = ?',
        whereArgs: [1, 1],
      );
      
      print('✅ [DEBUG] Registros eliminados limpiados: $count');
      
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error al limpiar registros eliminados: $e');
      print('Stack trace: $stackTrace');
      // No relanzamos la excepción para no interrumpir el flujo de la aplicación
    }
  }
}
