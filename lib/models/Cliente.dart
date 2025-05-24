class Cliente {
  final int? id;
  String nombre;
  final String telefono;

  Cliente({this.id, required this.nombre, required this.telefono});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'telefono': telefono,
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'],
      nombre: map['nombre'],
      telefono: map['telefono'],
    );
  }
}
