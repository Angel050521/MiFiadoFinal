import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../models/movimiento.dart';
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
      version: 16, // o el siguiente número de versión
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
          monto REAL,
          fecha TEXT,
          descripcion TEXT,
          FOREIGN KEY (productoId) REFERENCES productos(id)
        );
      ''');
    }
    
    if (oldVersion < 5) {
      // Migración para la versión 5 - Agregar campos de sincronización
      try {
        // Agregar columnas de sincronización a las tablas existentes
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
    
    if (oldVersion < 6) {
      // Migración para la versión 6 - Renombrar columna 'cantidad' a 'monto' en la tabla movimientos
      try {
        // Verificar si la columna 'cantidad' existe
        final columns = await db.rawQuery('PRAGMA table_info(movimientos)');
        final hasCantidad = columns.any((col) => col['name'] == 'cantidad');
        final hasMonto = columns.any((col) => col['name'] == 'monto');
        
        if (hasCantidad && !hasMonto) {
          // 1. Crear una nueva tabla temporal con la estructura correcta
          await db.execute('''
            CREATE TABLE movimientos_new (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              productoId INTEGER,
              tipo TEXT,
              monto REAL,
              fecha TEXT,
              descripcion TEXT,
              FOREIGN KEY (productoId) REFERENCES productos(id)
            );
          ''');
          
          // 2. Copiar los datos de la tabla antigua a la nueva
          await db.execute('''
            INSERT INTO movimientos_new (id, productoId, tipo, monto, fecha, descripcion)
            SELECT id, productoId, tipo, cantidad, fecha, descripcion FROM movimientos;
          ''');
          
          // 3. Eliminar la tabla antigua
          await db.execute('DROP TABLE movimientos;');
          
          // 4. Renombrar la nueva tabla
          await db.execute('ALTER TABLE movimientos_new RENAME TO movimientos;');
          
          print('✅ [MIGRACION] Columna "cantidad" renombrada a "monto" en la tabla movimientos');
        } else if (hasMonto) {
          print('ℹ️ [MIGRACION] La columna "monto" ya existe en la tabla movimientos');
        } else {
          print('ℹ️ [MIGRACION] No se encontró la columna "cantidad" en la tabla movimientos');
        }
      } catch (e, stackTrace) {
        print('❌ [ERROR] Error en migración a versión 6: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }
    
    
    if (oldVersion < 7) {
      // Migración para la versión 7 - Agregar columnas a la tabla productos
      try {
        // Verificar si las columnas ya existen
        final columns = await db.rawQuery('PRAGMA table_info(productos)');
        final hasDescripcion = columns.any((col) => col['name'] == 'descripcion');
        final hasFechaCreacion = columns.any((col) => col['name'] == 'fecha_creacion');
        
        if (!hasDescripcion) {
          await db.execute('ALTER TABLE productos ADD COLUMN descripcion TEXT');
          print('✅ [MIGRACION] Columna "descripcion" agregada a la tabla productos');
        } else {
          print('ℹ️ [MIGRACION] La columna "descripcion" ya existe en la tabla productos');
        }
        
        if (!hasFechaCreacion) {
          await db.execute('ALTER TABLE productos ADD COLUMN fecha_creacion TEXT');
          print('✅ [MIGRACION] Columna "fecha_creacion" agregada a la tabla productos');
        } else {
          print('ℹ️ [MIGRACION] La columna "fecha_creacion" ya existe en la tabla productos');
        }
        
      } catch (e, stackTrace) {
        print('❌ [ERROR] Error en migración a versión 7: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }
    
    if (oldVersion < 8) {
      // Migración para la versión 8 - Agregar campos a productos
      try {
        // Verificar si las columnas ya existen
        final columns = await db.rawQuery('PRAGMA table_info(productos)');
        final hasDescripcion = columns.any((col) => col['name'] == 'descripcion');
        final hasFechaCreacion = columns.any((col) => col['name'] == 'fecha_creacion');
        
        if (!hasDescripcion) {
          await db.execute('ALTER TABLE productos ADD COLUMN descripcion TEXT');
          print('✅ [MIGRACION] Columna "descripcion" agregada a la tabla productos');
        } else {
          print('ℹ️ [MIGRACION] La columna "descripcion" ya existe en la tabla productos');
        }
        
        if (!hasFechaCreacion) {
          await db.execute('ALTER TABLE productos ADD COLUMN fecha_creacion TEXT');
          print('✅ [MIGRACION] Columna "fecha_creacion" agregada a la tabla productos');
        } else {
          print('ℹ️ [MIGRACION] La columna "fecha_creacion" ya existe en la tabla productos');
        }
      } catch (e, stackTrace) {
        print('❌ [ERROR] Error en migración a versión 8: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }
    
    if (oldVersion < 9) {
      // Migración para la versión 9 - Actualizar estructura de la tabla gastos
      try {
        // Verificar si la tabla gastos existe
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='gastos'"
        );
        
        if (tables.isNotEmpty) {
          // Verificar si la columna 'descripcion' existe (esquema antiguo)
          final columns = await db.rawQuery('PRAGMA table_info(gastos)');
          final hasDescripcion = columns.any((col) => col['name'] == 'descripcion');
          
          if (hasDescripcion) {
            // Crear una tabla temporal con el nuevo esquema
            await db.execute('''
              CREATE TABLE gastos_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                concepto TEXT,
                monto REAL,
                fecha TEXT
              );
            ''');
            
            // Copiar los datos de la tabla antigua a la nueva
            await db.execute('''
              INSERT INTO gastos_new (id, concepto, monto, fecha)
              SELECT id, descripcion as concepto, cantidad as monto, fecha FROM gastos
            ''');
            
            // Eliminar la tabla antigua
            await db.execute('DROP TABLE gastos');
            
            // Renombrar la nueva tabla
            await db.execute('ALTER TABLE gastos_new RENAME TO gastos');
            
            print('✅ [MIGRACION] Tabla gastos actualizada: descripcion -> concepto, cantidad -> monto');
          } else {
            print('ℹ️ [MIGRACION] La tabla gastos ya tiene la estructura actualizada');
          }
        } else {
          print('ℹ️ [MIGRACION] La tabla gastos no existe, se creará con la estructura correcta');
        }
      } catch (e, stackTrace) {
        print('❌ [ERROR] Error en migración de tabla gastos: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }
    
    if (oldVersion < 10) {
      // Migración para la versión 10 - Renombrar productoId a producto_id en movimientos
      try {
        // Verificar si la tabla movimientos existe
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='movimientos'"
        );
        
        if (tables.isNotEmpty) {
          // Verificar si la columna productoId existe
          final columns = await db.rawQuery('PRAGMA table_info(movimientos)');
          final hasProductoId = columns.any((col) => col['name'] == 'productoId');
          
          if (hasProductoId) {
            // Crear una tabla temporal con el nuevo esquema
            await db.execute('''
              CREATE TABLE movimientos_new (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                producto_id INTEGER,
                tipo TEXT,
                monto REAL,
                fecha TEXT,
                descripcion TEXT,
                FOREIGN KEY (producto_id) REFERENCES productos(id)
              );
            ''');
            
            // Copiar los datos de la tabla antigua a la nueva
            await db.execute('''
              INSERT INTO movimientos_new (id, producto_id, tipo, monto, fecha, descripcion)
              SELECT id, productoId, tipo, monto, fecha, descripcion FROM movimientos
            ''');
            
            // Eliminar la tabla antigua
            await db.execute('DROP TABLE movimientos');
            
            // Renombrar la nueva tabla
            await db.execute('ALTER TABLE movimientos_new RENAME TO movimientos');
            
            print('✅ [MIGRACION] Columna "productoId" renombrada a "producto_id" en la tabla movimientos');
          } else {
            print('ℹ️ [MIGRACION] La columna "productoId" no existe en la tabla movimientos');
          }
        } else {
          print('ℹ️ [MIGRACION] La tabla movimientos no existe, no es necesaria la migración');
        }
      } catch (e, stackTrace) {
        print('❌ [ERROR] Error en migración a versión 9: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }
    
    if (oldVersion < 11) {
      // Migración para agregar createdAt y updatedAt a pedidos
      try {
        final columns = await db.rawQuery('PRAGMA table_info(pedidos)');
        final hasCreatedAt = columns.any((col) => col['name'] == 'createdAt');
        final hasUpdatedAt = columns.any((col) => col['name'] == 'updatedAt');

        if (!hasCreatedAt) {
          await db.execute('ALTER TABLE pedidos ADD COLUMN createdAt TEXT');
          print('✅ [MIGRACION] Columna "createdAt" agregada a la tabla pedidos');
        } else {
          print('ℹ️ [MIGRACION] La columna "createdAt" ya existe en la tabla pedidos');
        }

        if (!hasUpdatedAt) {
          await db.execute('ALTER TABLE pedidos ADD COLUMN updatedAt TEXT');
          print('✅ [MIGRACION] Columna "updatedAt" agregada a la tabla pedidos');
        } else {
          print('ℹ️ [MIGRACION] La columna "updatedAt" ya existe en la tabla pedidos');
        }
      } catch (e, stackTrace) {
        print('❌ [ERROR] Error en migración a versión 11: $e');
        print('Stack trace: $stackTrace');
        rethrow;
      }
    }

    if (oldVersion < 16) {
  final columns = await db.rawQuery('PRAGMA table_info(pedidos)');
  final hasCreatedAt = columns.any((col) => col['name'] == 'createdAt');
  final hasUpdatedAt = columns.any((col) => col['name'] == 'updatedAt');

  if (!hasCreatedAt) {
    await db.execute('ALTER TABLE pedidos ADD COLUMN createdAt TEXT');
    print('✅ [MIGRACION] Columna "createdAt" agregada a la tabla pedidos');
  } else {
    print('ℹ️ [MIGRACION] La columna "createdAt" ya existe en la tabla pedidos');
  }

  if (!hasUpdatedAt) {
    await db.execute('ALTER TABLE pedidos ADD COLUMN updatedAt TEXT');
    print('✅ [MIGRACION] Columna "updatedAt" agregada a la tabla pedidos');
  } else {
    print('ℹ️ [MIGRACION] La columna "updatedAt" ya existe en la tabla pedidos');
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
        cliente_id INTEGER,
        deuda REAL,
        descripcion TEXT,
        fecha_creacion TEXT,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id)
      );
    ''');

    await db.execute('''
      CREATE TABLE movimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER,
        tipo TEXT,
        monto REAL,
        fecha TEXT,
        descripcion TEXT,
        FOREIGN KEY (producto_id) REFERENCES productos(id)
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
    createdAt TEXT,
    updatedAt TEXT,
    FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE SET NULL
  );
''');




    await db.execute('''
      CREATE TABLE gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        concepto TEXT,
        monto REAL,
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
    Database? db;
    try {
      print('🔄 [DEBUG] Iniciando insertCliente');
      print('   - Nombre: ${cliente.nombre}');
      print('   - Teléfono: ${cliente.telefono}');
      
      db = await instance.database;
      print('   - Base de datos obtenida');
      
      // Iniciar una transacción
      await db.transaction((txn) async {
        // Insertar el cliente
        final map = cliente.toMap();
        print('   - Mapa del cliente: $map');
        
        final id = await txn.insert('clientes', map);
        print('✅ [DEBUG] Cliente insertado con ID: $id');
        
        // Crear un producto de "Cuenta Principal" para el cliente
        final productoPrincipal = Producto(
          clienteId: id.toString(),
          nombre: 'Cuenta Principal',
          descripcion: 'Producto principal para registrar movimientos generales',
          fechaCreacion: DateTime.now().toIso8601String(),
        );
        
        print('🔄 [DEBUG] Creando producto de Cuenta Principal');
        await txn.insert('productos', productoPrincipal.toMap());
        print('✅ [DEBUG] Producto "Cuenta Principal" creado para el cliente ID: $id');
        
        // Verificar que el cliente se haya guardado correctamente
        final clienteGuardado = await txn.query(
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
      });
      
      // Si llegamos aquí, la transacción fue exitosa
      // Obtener el ID del cliente recién insertado
      final clienteInsertado = await db.query(
        'clientes',
        where: 'rowid = last_insert_rowid()',
      );
      
      if (clienteInsertado.isNotEmpty) {
        final clienteId = clienteInsertado.first['id'] as int;
        print('✅ [DEBUG] Cliente confirmado en la base de datos con ID: $clienteId');
        return clienteId;
      } else {
        // Si no se encuentra por last_insert_rowid, intentar por teléfono solo si no está vacío
        if (cliente.telefono.isNotEmpty) {
          final porTelefono = await db.query(
            'clientes',
            where: 'telefono = ?',
            whereArgs: [cliente.telefono],
            orderBy: 'id DESC',
            limit: 1,
          );
          
          if (porTelefono.isNotEmpty) {
            final clienteId = porTelefono.first['id'] as int;
            print('✅ [DEBUG] Cliente confirmado por teléfono con ID: $clienteId');
            return clienteId;
          }
        }
        
        // Si llegamos aquí, no se pudo confirmar la creación
        throw Exception('No se pudo confirmar la creación del cliente');
      }
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en insertCliente: $e');
      print('Stack trace: $stackTrace');
      
      // No intentamos recuperarnos automáticamente ya que podría causar duplicados
      // Si hay un error, lo mejor es que falle la operación completa
      // y que el usuario lo intente de nuevo
      
      // Si el cliente se quedó en un estado inconsistente, el usuario deberá eliminarlo manualmente
      if (db != null) {
        try {
          // Primero buscar por ID si está disponible
          if (cliente.id != null && cliente.id!.isNotEmpty) {
            final clienteExistente = await db.query(
              'clientes',
              where: 'id = ?',
              whereArgs: [cliente.id],
            );
            
            if (clienteExistente.isNotEmpty) {
              final clienteId = clienteExistente.first['id'] as int;
              print('⚠️ [WARNING] Cliente puede haber quedado en estado inconsistente. ID: $clienteId');
              return clienteId; // Devolver el ID del cliente inconsistente
            }
          }
          
          // Si no se encontró por ID o no hay ID, intentar por teléfono si no está vacío
          if (cliente.telefono.isNotEmpty) {
            final clientePorTelefono = await db.query(
              'clientes',
              where: 'telefono = ?',
              whereArgs: [cliente.telefono],
            );
            
            if (clientePorTelefono.isNotEmpty) {
              final clienteId = clientePorTelefono.first['id'] as int;
              print('⚠️ [WARNING] Cliente puede haber quedado en estado inconsistente (búsqueda por teléfono). ID: $clienteId');
            }
          }
        } catch (e2) {
          print('❌ [ERROR] Error al verificar el estado del cliente: $e2');
        }
      }
      
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
    try {
      print('🔄 [DEBUG] Insertando producto para cliente_id: ${producto.clienteId}');
      final db = await instance.database;
      final map = producto.toMap();
      print('   - Mapa del producto: $map');
      final id = await db.insert('productos', map);
      print('✅ [DEBUG] Producto insertado con ID: $id');
      return id;
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en insertProducto: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<List<Producto>> getProductosPorCliente(int clienteId) async {
    try {
      print('🔄 [DEBUG] Obteniendo productos para cliente_id: $clienteId');
      final db = await instance.database;
      final result = await db.query(
        'productos', 
        where: 'cliente_id = ?', 
        whereArgs: [clienteId]
      );
      print('✅ [DEBUG] Productos encontrados: ${result.length}');
      return result.map((json) => Producto.fromMap(json)).toList();
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en getProductosPorCliente: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<int> updateProducto(Producto producto) async {
    try {
      print('🔄 [DEBUG] Actualizando producto ID: ${producto.id}');
      final db = await instance.database;
      final result = await db.update(
        'productos', 
        producto.toMap(), 
        where: 'id = ?', 
        whereArgs: [producto.id]
      );
      print('✅ [DEBUG] Producto actualizado: $result filas afectadas');
      return result;
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en updateProducto: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<int> eliminarProducto(String id) async {
    try {
      print('🔄 [DEBUG] Eliminando producto ID: $id');
      final db = await instance.database;
      final result = await db.delete(
        'productos', 
        where: 'id = ?', 
        whereArgs: [id]
      );
      print('✅ [DEBUG] Producto eliminado: $result filas afectadas');
      return result;
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en eliminarProducto: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
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
        where: 'producto_id = ?', 
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
    try {
      print('🔄 [PEDIDO] Iniciando inserción de pedido');
      print('   - Cliente: ${pedido.clienteNombre}');
      print('   - Título: ${pedido.titulo}');
      print('   - Fecha entrega: ${pedido.fechaEntrega}');
      print('   - Precio: ${pedido.precio}');
      
      final db = await instance.database;
      final map = pedido.toMap();
      print('   - Datos a insertar: $map');
      
      final id = await db.insert('pedidos', map);
      print('✅ [PEDIDO] Pedido insertado correctamente con ID: $id');
      
      return id;
    } catch (e, stackTrace) {
      print('❌ [ERROR PEDIDO] Error al insertar pedido: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> insertOrUpdatePedido(Pedido pedido) async {
  final db = await database;
  if (pedido.id == null) {
    // Insertar nuevo pedido
    await db.insert('pedidos', pedido.toMap());
  } else {
    // Intentar actualizar
    final count = await db.update(
      'pedidos',
      pedido.toMap(),
      where: 'id = ?',
      whereArgs: [pedido.id],
    );
    if (count == 0) {
      // Si no existía, insertar con el ID original
      final map = pedido.toMap();
      map['id'] = int.tryParse(pedido.id!) ?? pedido.id;
      await db.insert('pedidos', map);
    }
  }
}

  Future<List<Pedido>> getPedidos() async {
    try {
      final db = await instance.database;
      final result = await db.query('pedidos');
      print('✅ [PEDIDO] Obtenidos ${result.length} pedidos de la base de datos');
      return result.map((json) => Pedido.fromMap(json)).toList();
    } catch (e) {
      print('❌ [ERROR PEDIDO] Error al obtener pedidos: $e');
      rethrow;
    }
  }

  Future<int> eliminarPedido(int id) async {
    final db = await instance.database;
    // Registrar eliminación lógica
    await db.insert('registros_eliminados', {
      'tipo': 'pedido',
      'id_original': id.toString(),
      'sincronizado': 0,
    });
    // Borrado físico
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

  Future<List<Pedido>> getPedidosPorCliente(int clienteId) async {
    try {
      print('🔍 [DEBUG] Buscando pedidos para clienteId: $clienteId');
      final db = await instance.database;
      
      // Verificar si la tabla existe
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='pedidos'"
      );
      print('📊 [DEBUG] Tabla pedidos existe: ${tables.isNotEmpty}');
      
      // Obtener los pedidos del cliente
      final result = await db.query(
        'pedidos', 
        where: 'cliente_id = ?', 
        whereArgs: [clienteId],
        orderBy: 'fecha_entrega ASC',
      );
      
      print('✅ [DEBUG] Pedidos encontrados: ${result.length}');
      return result.map((json) => Pedido.fromMap(json)).toList();
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error al obtener pedidos: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
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
  
  Future<void> eliminarTodosLosPedidos() async {
  final db = await instance.database;
  await db.delete('pedidos');
}

Future<List<Map<String, dynamic>>> query(
  String table, {
  String? where,
  List<Object?>? whereArgs,
}) async {
  final db = await database;
  return db.query(table, where: where, whereArgs: whereArgs);
}
}
