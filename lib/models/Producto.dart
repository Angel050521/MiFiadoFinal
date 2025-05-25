class Producto {
  final int? id;
  final int clienteId;
  final String nombre;
  final String? descripcion; // 👈 CAMBIA ESTO
  final String fechaCreacion;

  Producto({
    this.id,
    required this.clienteId,
    required this.nombre,
    this.descripcion, // 👈 QUITA required
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'cliente_id': clienteId,
    'nombre': nombre,
    'descripcion': descripcion,
    'fecha_creacion': fechaCreacion,
  };

  factory Producto.fromMap(Map<String, dynamic> map) => Producto(
    id: map['id'],
    clienteId: map['cliente_id'],
    nombre: map['nombre'],
    descripcion: map['descripcion'],
    fechaCreacion: map['fecha_creacion'],
  );
}
