class Producto {
  final String? id;
  final String clienteId;
  final String nombre;
  final String descripcion;
  final String fechaCreacion;

  Producto({
    this.id,
    required this.clienteId,
    required this.nombre,
    String? descripcion,
    String? fechaCreacion,
  }) : descripcion = descripcion ?? '',
       fechaCreacion = fechaCreacion ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    final clienteIdInt = int.tryParse(clienteId) ?? 0;
    return {
      'id': id != null ? int.tryParse(id!) : null,
      'cliente_id': clienteIdInt,
      'nombre': nombre,
      'descripcion': descripcion,
      'fecha_creacion': fechaCreacion,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) => Producto(
    id: map['id']?.toString(),
    clienteId: map['cliente_id']?.toString() ?? '0', // Mapeamos desde cliente_id
    nombre: map['nombre'] as String,
    descripcion: map['descripcion'] as String?,
    fechaCreacion: map['fecha_creacion'] as String,
  );

  factory Producto.fromFirestore(Map<String, dynamic> data, String id) => Producto(
    id: id,
    clienteId: data['cliente_id']?.toString() ?? '0',
    nombre: data['nombre'] as String,
    descripcion: data['descripcion'] as String?,
    fechaCreacion: data['fecha_creacion'] as String,
  );
}
