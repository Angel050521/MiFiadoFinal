class Pedido {
  final String? id;
  final int? clienteId;
  final String? clienteNombre;
  final String? clienteTelefono;
  final String titulo;
  final String descripcion;
  final DateTime? fechaEntrega;
  final double? precio;
  final bool hecho;
  final DateTime? fechaHecho;

  Pedido({
    this.id,
    this.clienteId,
    this.clienteNombre,
    this.clienteTelefono,
    required this.titulo,
    required this.descripcion,
    this.fechaEntrega,
    this.precio,
    this.hecho = false,
    this.fechaHecho,
  });

  factory Pedido.fromMap(Map<String, Object?> m) {
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

    // Soporta snake_case y camelCase
    final clienteId = m['cliente_id'] as int? ??
        int.tryParse(m['cliente_id']?.toString() ?? '') ??
        m['clienteId'] as int?;
    final clienteNombre = m['cliente_nombre'] as String? ?? m['clienteNombre'] as String?;
    final clienteTelefono = m['cliente_telefono'] as String? ?? m['clienteTelefono'] as String?;

    print('DEBUG Pedido.fromMap: $m');

    return Pedido(
      id: m['id']?.toString(),
      clienteId: clienteId,
      clienteNombre: clienteNombre,
      clienteTelefono: clienteTelefono,
      titulo: m['titulo'] as String? ?? '',
      descripcion: m['descripcion'] as String? ?? '',
      fechaEntrega: parseDate(m['fechaEntrega'] ?? m['fecha_entrega']),
      precio: (m['precio'] as num?)?.toDouble(),
      hecho: (m['hecho'] is int ? (m['hecho'] as int) == 1 : (m['hecho'] as bool?) ?? false),
      fechaHecho: parseDate(m['fechaHecho'] ?? m['fecha_hecho']),
    );
  }

  Map<String, dynamic> toMap() {
    final dynamic idValue = id != null ? int.tryParse(id!) ?? id : null;
    return {
      'id': idValue,
      'cliente_id': clienteId,
      'cliente_nombre': clienteNombre,
      'cliente_telefono': clienteTelefono,
      'titulo': titulo,
      'descripcion': descripcion,
      'fecha_entrega': fechaEntrega?.toIso8601String(),
      'precio': precio,
      'hecho': hecho ? 1 : 0,
      'fecha_hecho': fechaHecho?.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }

  Pedido copyWith({
    String? id,
    int? clienteId,
    String? clienteNombre,
    String? clienteTelefono,
    String? titulo,
    String? descripcion,
    DateTime? fechaEntrega,
    double? precio,
    bool? hecho,
    DateTime? fechaHecho,
  }) {
    return Pedido(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      clienteTelefono: clienteTelefono ?? this.clienteTelefono,
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
    clienteId: data['cliente_id'] as int? ?? 0,
    clienteNombre: data['cliente_nombre'] as String,
    clienteTelefono: data['cliente_telefono'] as String?,
    titulo: data['titulo'] as String,
    descripcion: data['descripcion'] as String,
    fechaEntrega: data['fechaEntrega']?.toDate(),
    precio: data['precio']?.toDouble(),
    hecho: data['hecho'] as bool? ?? false,
    fechaHecho: data['fechaHecho']?.toDate(),
  );
}
