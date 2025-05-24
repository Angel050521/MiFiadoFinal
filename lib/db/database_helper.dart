import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../models/producto.dart';

class DatabaseHelper {
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
      version: 2,
      onCreate: _onCreate,
    );
  }

  Future _onCreate(Database db, int version) async {
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
  }

  // CLIENTES
  Future<int> insertCliente(Cliente cliente) async {
    final db = await database;
    return await db.insert('clientes', cliente.toMap());
  }

  Future<List<Cliente>> getClientes() async {
    final db = await database;
    final maps = await db.query('clientes', orderBy: 'nombre ASC');
    return maps.map((map) => Cliente.fromMap(map)).toList();
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
    return maps.map((map) => Producto.fromMap(map)).toList();
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
    return maps.map((map) => Movimiento.fromMap(map)).toList();
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
    final result = await db.query('usuarios',
      where: 'email = ? AND password = ?',
      whereArgs: [email.trim().toLowerCase(), password.trim()],
    );
    return result.isNotEmpty ? result.first : null;
  }
}