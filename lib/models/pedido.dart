class Pedido {
  final String? id;
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

  factory Pedido.fromMap(Map<String, Object?> m) {
    // Handle both snake_case and camelCase field names from database
    final cliente = m['cliente'] as String? ?? m['cliente_nombre'] as String? ?? '';
    final telefono = m['telefono'] as String? ?? m['cliente_telefono'] as String?;
    
    // For date fields, try both formats and handle potential parsing errors
    DateTime? parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      try {
        if (dateValue is DateTime) return dateValue;
        if (dateValue is String) return DateTime.parse(dateValue);
        return null;
      } catch (e) {
        print('Error parsing date: $e');
        return null;
      }
    }
    
    return Pedido(
      id: m['id']?.toString(),
      cliente: cliente,
      telefono: telefono,
      titulo: m['titulo'] as String? ?? '',
      descripcion: m['descripcion'] as String? ?? '',
      fechaEntrega: parseDate(m['fechaEntrega'] ?? m['fecha_entrega']),
      precio: (m['precio'] as num?)?.toDouble(),
      hecho: (m['hecho'] is int ? (m['hecho'] as int) == 1 : (m['hecho'] as bool?) ?? false),
      fechaHecho: parseDate(m['fechaHecho'] ?? m['fecha_hecho']),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id != null ? int.tryParse(id!) : null,
      'cliente_id': int.tryParse(cliente), // Asumiendo que cliente es el ID como string
      'cliente_nombre': cliente, // Guardamos el nombre del cliente
      'cliente_telefono': telefono ?? '',
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha_entrega': fechaEntrega?.toIso8601String(),
      'precio': precio,
      'hecho': hecho ? 1 : 0,
      'fecha_hecho': fechaHecho?.toIso8601String(),
    };
  }

  Pedido copyWith({
    String? id,
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


  factory Pedido.fromFirestore(Map<String, dynamic> data, String id) => Pedido(
    id: id,
    cliente: data['cliente'] as String,
    titulo: data['titulo'] as String,
    descripcion: data['descripcion'] as String,
    fechaEntrega: data['fechaEntrega']?.toDate(),
    precio: data['precio']?.toDouble(),
    hecho: data['hecho'] as bool? ?? false,
    fechaHecho: data['fechaHecho']?.toDate(),
  );
}
