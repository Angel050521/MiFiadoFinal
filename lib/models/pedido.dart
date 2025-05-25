class Pedido {
  final int? id;
  final String cliente;
  final String? telefono;    // nueva propiedad
  final String titulo;
  final String descripcion;
  final DateTime? fechaEntrega;
  final double? precio;
  final bool hecho;

  Pedido({
    this.id,
    required this.cliente,
    this.telefono,
    required this.titulo,
    required this.descripcion,
    this.fechaEntrega,
    this.precio,
    this.hecho = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id'           : id,
      'cliente'      : cliente,
      'telefono'     : telefono,
      'titulo'       : titulo,
      'descripcion'  : descripcion,
      'fechaEntrega' : fechaEntrega?.toIso8601String(),
      'precio'       : precio,
      'hecho'        : hecho ? 1 : 0,
    };
  }

  factory Pedido.fromMap(Map<String, dynamic> map) {
    return Pedido(
      id: map['id'] as int?,
      cliente: map['cliente'] as String,
      telefono: map['telefono'] as String?,
      titulo: map['titulo'] as String,
      descripcion: map['descripcion'] as String,
      fechaEntrega: map['fechaEntrega'] != null
          ? DateTime.parse(map['fechaEntrega'] as String)
          : null,
      precio: map['precio'] != null
          ? (map['precio'] as num).toDouble()
          : null,
      hecho: (map['hecho'] as int) == 1,
    );
  }

  Pedido copyWith({
    int? id,
    String? cliente,
    String? telefono,
    String? titulo,
    String? descripcion,
    DateTime? fechaEntrega,
    double? precio,
    bool? hecho,
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
    );
  }
}