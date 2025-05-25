class Pedido {
  final int? id;
  final String cliente;
  final String titulo;
  final String descripcion;
  final DateTime? fechaEntrega;
  final double? precio;
  final bool hecho;

  Pedido({
    this.id,
    required this.cliente,
    required this.titulo,
    required this.descripcion,
    this.fechaEntrega,
    this.precio,
    this.hecho = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'cliente': cliente,
    'titulo': titulo,
    'descripcion': descripcion,
    'fecha_entrega': fechaEntrega?.toIso8601String(),
    'precio': precio,
    'hecho': hecho ? 1 : 0,
  };

  factory Pedido.fromMap(Map<String, dynamic> map) => Pedido(
    id: map['id'] as int?,
    cliente: map['cliente'] as String,
    titulo: map['titulo'] as String,
    descripcion: map['descripcion'] as String,
    fechaEntrega: map['fecha_entrega'] != null
        ? DateTime.parse(map['fecha_entrega'] as String)
        : null,
    precio: (map['precio'] as num?)?.toDouble(),
    hecho: (map['hecho'] as int? ?? 0) == 1,
  );

  // 🚩 Este método te permite copiar el pedido cambiando solo los campos necesarios
  Pedido copyWith({
    int? id,
    String? cliente,
    String? titulo,
    String? descripcion,
    DateTime? fechaEntrega,
    double? precio,
    bool? hecho,
  }) {
    return Pedido(
      id: id ?? this.id,
      cliente: cliente ?? this.cliente,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      precio: precio ?? this.precio,
      hecho: hecho ?? this.hecho,
    );
  }
}
