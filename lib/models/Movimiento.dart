class Movimiento {
  final String? id;
  final String productoId;
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
    final productoIdInt = int.tryParse(productoId) ?? 0;
    return {
      'id': id != null ? int.tryParse(id!) : null,
      'producto_id': productoIdInt, // Use only snake_case for database
      'fecha': fecha,
      'tipo': tipo,
      'monto': monto,
      'descripcion': descripcion,
    };
  }

  factory Movimiento.fromMap(Map<String, dynamic> map) {
    try {
      // Handle both snake_case and camelCase field names for productoId
      final productoId = (map['productoId'] ?? map['producto_id'] ?? 0).toString();
      
      // Handle both 'monto' and 'cantidad' fields
      final monto = (map['monto'] ?? map['cantidad'] ?? 0.0).toDouble();
      
      // Ensure id is properly handled whether it comes as int or String
      final id = map['id']?.toString();
      
      // Ensure fecha is a valid string
      String fecha;
      try {
        fecha = map['fecha'] as String? ?? DateTime.now().toIso8601String();
      } catch (e) {
        fecha = DateTime.now().toIso8601String();
      }
      
      // Ensure tipo is valid
      final tipo = (map['tipo'] as String?)?.toLowerCase() == 'abono' ? 'abono' : 'cargo';
      
      // Ensure monto is a double
      double montoFinal;
      try {
        montoFinal = (monto is num) ? monto.toDouble() : double.tryParse(monto.toString()) ?? 0.0;
      } catch (e) {
        montoFinal = 0.0;
      }
      
      // Ensure descripcion is a non-null string
      final descripcion = map['descripcion']?.toString() ?? '';
      
      return Movimiento(
        id: id,
        productoId: productoId, // Usar la variable productoId que ya tenemos
        fecha: fecha,
        tipo: tipo,
        monto: montoFinal,
        descripcion: descripcion,
      );
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en Movimiento.fromMap: $e');
      print('Mapa recibido: $map');
      print('Stack trace: $stackTrace');
      
      // Return a default Movimiento object to prevent crashes
      return Movimiento(
        productoId: '0',
        fecha: DateTime.now().toIso8601String(),
        tipo: 'cargo',
        monto: 0.0,
        descripcion: 'Error al cargar movimiento',
      );
    }
  }

  factory Movimiento.fromFirestore(Map<String, dynamic> data, String id) {
    // Handle both 'monto' and 'cantidad' fields
    final monto = data['monto'] ?? data['cantidad'] ?? 0.0;
    
    return Movimiento(
      id: id,
      productoId: (data['producto_id'] ?? data['productoId'] ?? '0').toString(),
      fecha: data['fecha'] as String? ?? DateTime.now().toIso8601String(),
      tipo: data['tipo'] as String? ?? 'cargo',
      monto: (monto as num).toDouble(),
      descripcion: data['descripcion'] as String? ?? '',
    );
  }
}