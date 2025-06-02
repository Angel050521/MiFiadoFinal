class Gasto {
  final String? id;
  final String concepto;
  final double monto;
  final DateTime fecha;

  Gasto({this.id, required this.concepto, required this.monto, required this.fecha});

  Map<String, dynamic> toMap() {
    return {
      'id': id != null ? int.tryParse(id!) : null,
      'concepto': concepto,
      'monto': monto,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory Gasto.fromMap(Map<String, dynamic> map) {
    return Gasto(
      id: map['id']?.toString(),
      concepto: map['concepto'] as String,
      monto: (map['monto'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha'] as String),
    );
  }

  factory Gasto.fromFirestore(Map<String, dynamic> data, String id) => Gasto(
    id: id,
    concepto: data['concepto'] as String,
    monto: (data['monto'] as num).toDouble(),
    fecha: (data['fecha'] as DateTime).toLocal(),
  );
}
