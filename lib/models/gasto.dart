class Gasto {
  final int? id;
  final String concepto;
  final double monto;
  final DateTime fecha;

  Gasto({this.id, required this.concepto, required this.monto, required this.fecha});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'concepto': concepto,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      id: map['id'],
      concepto: map['concepto'],
      monto: map['monto'],
      fecha: DateTime.parse(map['fecha']),
    );
  }
}
