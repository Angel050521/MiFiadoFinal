import '../models/cliente.dart';
import '../models/movimiento.dart';

Map<String, dynamic> clienteToMap(Cliente c) {
  return {
    'id': c.id,
    'nombre': c.nombre,
    'telefono': c.telefono,
  };
}

Map<String, dynamic> movimientoToMap(Movimiento m) {
  return {
    'id': m.id,
    'productoId': m.productoId, //
    'fecha': m.fecha,
    'tipo': m.tipo,
    'monto': m.monto,
    'descripcion': m.descripcion,
  };
}
