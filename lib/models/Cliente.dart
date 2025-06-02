class Cliente {
  final String? id;
  String nombre;
  final String telefono;

  Cliente({this.id, required this.nombre, required this.telefono});

  Map<String, dynamic> toMap() {
    return {
      'id': id != null ? int.tryParse(id!) : null,
      'nombre': nombre,
      'telefono': telefono,
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id']?.toString(),
      nombre: map['nombre'] as String,
      telefono: map['telefono'] as String,
    );
  }

  factory Cliente.fromFirestore(Map<String, dynamic> data, String id) => Cliente(
    id: id,
    nombre: data['nombre'] as String,
    telefono: data['telefono'] as String,
  );
}
