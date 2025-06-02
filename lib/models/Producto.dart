class Producto {
  final String? id;
  final String clienteId;
  final String nombre;
  final String? descripcion;
  final String fechaCreacion;

  Producto({
    this.id,
    required this.clienteId,
    required this.nombre,
    this.descripcion,
    required this.fechaCreacion,
  });

  Map<String, dynamic> toMap() => {
    'id': id != null ? int.tryParse(id!) : null,
    'cliente_id': int.tryParse(clienteId),
    'nombre': nombre,
    'descripcion': descripcion,
    'fecha_creacion': fechaCreacion,
  };

  factory Producto.fromMap(Map<String, dynamic> map) => Producto(
    id: map['id']?.toString(),
    clienteId: map['cliente_id'].toString(),
    nombre: map['nombre'] as String,
    descripcion: map['descripcion'] as String?,
    fechaCreacion: map['fecha_creacion'] as String,
  );

  factory Producto.fromFirestore(Map<String, dynamic> data, String id) => Producto(
    id: id,
    clienteId: data['cliente_id'] as String,
    nombre: data['nombre'] as String,
    descripcion: data['descripcion'] as String?,
    fechaCreacion: data['fecha_creacion'] as String,
  );
}
