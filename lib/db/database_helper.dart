import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../models/producto.dart';
import '../models/pedido.dart';
import '../models/gasto.dart';

class DatabaseHelper {
  // --- GASTOS ---
  Future<int> insertGasto(Gasto gasto) async {
    final db = await database;
    return await db.insert('gastos', gasto.toMap());
  }

  Future<List<Gasto>> getGastos() async {
    final db = await database;
    final maps = await db.query('gastos', orderBy: 'fecha DESC');
    return maps.map((m) => Gasto.fromMap(m)).toList();
  }

  Future<List<Gasto>> getGastosDelMes(DateTime fecha) async {
    final db = await database;
    final primerDiaMes = DateTime(fecha.year, fecha.month, 1);
    final hoy = DateTime(fecha.year, fecha.month, fecha.day, 23, 59, 59);
    final maps = await db.query(
      'gastos',
      where: 'fecha >= ? AND fecha <= ?',
      whereArgs: [primerDiaMes.toIso8601String(), hoy.toIso8601String()],
      orderBy: 'fecha DESC',
    );
    return maps.map((m) => Gasto.fromMap(m)).toList();
  }

  Future<void> eliminarGasto(int id) async {
    final db = await database;
    await db.delete('gastos', where: 'id = ?', whereArgs: [id]);
  }

  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fiados.db');
    return await openDatabase(
      path,
      version: 3,                  // bumped to 3 to support telefono
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        telefono TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        fecha_creacion TEXT NOT NULL,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE movimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        producto_id INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        tipo TEXT NOT NULL CHECK(tipo IN ('cargo', 'abono')),
        monto REAL NOT NULL,
        descripcion TEXT,
        FOREIGN KEY (producto_id) REFERENCES productos(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE pedidos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente TEXT NOT NULL,
        telefono TEXT,
        titulo TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        fechaEntrega TEXT,
        precio REAL,
        hecho INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // NUEVO: tabla gastos
    await db.execute('''
      CREATE TABLE gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        concepto TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // migración para fechaEntrega y precio
      await db.execute('ALTER TABLE pedidos ADD COLUMN fechaEntrega TEXT;');
      await db.execute('ALTER TABLE pedidos ADD COLUMN precio       REAL;');
    }
    if (oldVersion < 3) {
      // migración para teléfono
      await db.execute('ALTER TABLE pedidos ADD COLUMN telefono TEXT;');
    }
    // Si la tabla gastos no existe, crearla
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        concepto TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');
  }

  // CLIENTES
  Future<int> insertCliente(Cliente cliente) async {
    final db = await database;
    return await db.insert('clientes', cliente.toMap());
  }

  Future<List<Cliente>> getClientes() async {
    final db = await database;
    final maps = await db.query('clientes', orderBy: 'nombre ASC');
    return maps.map((m) => Cliente.fromMap(m)).toList();
  }

  Future<void> eliminarCliente(int id) async {
    final db = await database;
    await db.delete('clientes', where: 'id = ?', whereArgs: [id]);
    await db.delete('productos', where: 'cliente_id = ?', whereArgs: [id]);
  }

  Future<void> actualizarCliente(Cliente cliente) async {
    final db = await database;
    await db.update('clientes', cliente.toMap(), where: 'id = ?', whereArgs: [cliente.id]);
  }

  // PRODUCTOS
  Future<int> insertProducto(Producto producto) async {
    final db = await database;
    return await db.insert('productos', producto.toMap());
  }

  Future<List<Producto>> getProductosPorCliente(int clienteId) async {
    final db = await database;
    final maps = await db.query('productos', where: 'cliente_id = ?', whereArgs: [clienteId]);
    return maps.map((m) => Producto.fromMap(m)).toList();
  }

  Future<void> eliminarProducto(int id) async {
    final db = await database;
    await db.delete('productos', where: 'id = ?', whereArgs: [id]);
    await db.delete('movimientos', where: 'producto_id = ?', whereArgs: [id]);
  }

  // MOVIMIENTOS
  Future<int> insertMovimiento(Movimiento mov) async {
    final db = await database;
    return await db.insert('movimientos', mov.toMap());
  }

  Future<List<Movimiento>> getMovimientosPorProducto(int productoId) async {
    final db = await database;
    final maps = await db.query('movimientos', where: 'producto_id = ?', whereArgs: [productoId]);
    return maps.map((m) => Movimiento.fromMap(m)).toList();
  }

  // USUARIOS
  Future<int> insertUsuario(String nombre, String email, String password) async {
    final db = await database;
    return await db.insert('usuarios', {
      'nombre': nombre.trim(),
      'email': email.trim().toLowerCase(),
      'password': password.trim(),
    });
  }

  Future<Map<String, dynamic>?> loginUsuario(String email, String password) async {
    final db = await database;
    final result = await db.query(
      'usuarios',
      where: 'email = ? AND password = ?',
      whereArgs: [email.trim().toLowerCase(), password.trim()],
    );
    return result.isNotEmpty ? result.first : null;
  }

  // PEDIDOS (CRUD)
  Future<int> insertPedido(Pedido pedido) async {
    final db = await database;
    return await db.insert('pedidos', pedido.toMap());
  }

  Future<List<Pedido>> getPedidos({bool soloPendientes = true}) async {
    final db = await database;
    final maps = await db.query(
      'pedidos',
      where: soloPendientes ? 'hecho = ?' : null,
      whereArgs: soloPendientes ? [0] : null,
      orderBy: 'fechaEntrega ASC',
    );
    return maps.map((m) => Pedido.fromMap(m)).toList();
  }

  /// Obtiene todos los pedidos, sin importar si están hechos o no
  Future<List<Pedido>> getAllPedidos() async {
    final db = await database;
    final maps = await db.query('pedidos', orderBy: 'fechaEntrega ASC');
    return maps.map((m) => Pedido.fromMap(m)).toList();
  }

  Future<int> updatePedido(Pedido pedido) async {
    final db = await database;
    return await db.update(
      'pedidos',
      pedido.toMap(),
      where: 'id = ?',
      whereArgs: [pedido.id],
    );
  }

  Future<void> eliminarPedido(int id) async {
    final db = await database;
    await db.delete('pedidos', where: 'id = ?', whereArgs: [id]);
  }
}