
-- Tabla de usuarios
CREATE TABLE IF NOT EXISTS usuarios (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password TEXT NOT NULL
);

-- Tabla de clientes
CREATE TABLE IF NOT EXISTS clientes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nombre TEXT NOT NULL,
  telefono TEXT
);

-- Tabla de productos
CREATE TABLE IF NOT EXISTS productos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cliente_id INTEGER NOT NULL,
  nombre TEXT NOT NULL,
  descripcion TEXT,
  fecha_creacion TEXT NOT NULL,
  FOREIGN KEY (cliente_id) REFERENCES clientes(id)
);

-- Tabla de movimientos
CREATE TABLE IF NOT EXISTS movimientos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  producto_id INTEGER NOT NULL,
  fecha TEXT NOT NULL,
  tipo TEXT NOT NULL CHECK(tipo IN ('cargo', 'abono')),
  monto REAL NOT NULL,
  descripcion TEXT,
  FOREIGN KEY (producto_id) REFERENCES productos(id)
);

-- Tabla de pedidos
CREATE TABLE IF NOT EXISTS pedidos (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  cliente TEXT,
  titulo TEXT,
  descripcion TEXT,
  fecha_entrega TEXT,
  precio REAL
);

-- Tabla para suscripciones
CREATE TABLE IF NOT EXISTS suscripciones (
  user_id INTEGER PRIMARY KEY,
  plan TEXT NOT NULL CHECK(plan IN ('gratis', 'nube', 'premium')),
  device_id TEXT,
  actualizado_en TEXT
);
