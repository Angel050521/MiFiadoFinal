class Movimiento {
  final int? id;
  final int productoId;
  final String fecha;
  final String tipo; // "cargo" o "abono"
  final double monto;
  final String descripcion;

  Movimiento({
    this.id,
    required this.productoId,
    required this.fecha,
    required this.tipo,
    required this.monto,
    required this.descripcion,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': productoId,
      'fecha': fecha,
      'tipo': tipo,
      'monto': monto,
      'descripcion': descripcion,
    };
  }

  factory Movimiento.fromMap(Map<String, dynamic> map) {
    return Movimiento(
      id: map['id'],
      productoId: map['producto_id'],
      fecha: map['fecha'],
      tipo: map['tipo'],
      monto: map['monto'],
      descripcion: map['descripcion'],
    );
  }
}