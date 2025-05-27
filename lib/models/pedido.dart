class Pedido {
  final int? id;
  final String cliente;
  final String? telefono;
  final String titulo;
  final String descripcion;
  final DateTime? fechaEntrega;
  final double? precio;
  final bool hecho;
  final DateTime? fechaHecho;

  Pedido({
    this.id,
    required this.cliente,
    this.telefono,
    required this.titulo,
    required this.descripcion,
    this.fechaEntrega,
    this.precio,
    this.hecho = false,
    this.fechaHecho,
  });

  factory Pedido.fromMap(Map<String, Object?> m) => Pedido(
    id: m['id'] as int?,
    cliente: m['cliente'] as String,
    telefono: m['telefono'] as String?,
    titulo: m['titulo'] as String,
    descripcion: m['descripcion'] as String,
    fechaEntrega: m['fechaEntrega'] == null
        ? null
        : DateTime.parse(m['fechaEntrega'] as String),
    precio: m['precio'] == null ? null : (m['precio'] as num).toDouble(),
    hecho: (m['hecho'] as int) == 1,
    fechaHecho: m['fechaHecho'] == null
        ? null
        : DateTime.parse(m['fechaHecho'] as String),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'cliente': cliente,
    'telefono': telefono,
    'titulo': titulo,
    'descripcion': descripcion,
    'fechaEntrega': fechaEntrega?.toIso8601String(),
    'precio': precio,
    'hecho': hecho ? 1 : 0,
    'fechaHecho': fechaHecho?.toIso8601String(),
  };

  Pedido copyWith({
    int? id,
    String? cliente,
    String? telefono,
    String? titulo,
    String? descripcion,
    DateTime? fechaEntrega,
    double? precio,
    bool? hecho,
    DateTime? fechaHecho,
  }) {
    return Pedido(
      id: id ?? this.id,
      cliente: cliente ?? this.cliente,
      telefono: telefono ?? this.telefono,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      precio: precio ?? this.precio,
      hecho: hecho ?? this.hecho,
      fechaHecho: fechaHecho ?? this.fechaHecho,
    );
  }
}
