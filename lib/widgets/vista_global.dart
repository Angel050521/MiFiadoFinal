import 'package:flutter/material.dart';
import '../models/producto.dart';

class VistaGlobal extends StatelessWidget {
  final double saldoTotal;
  final Map<int, double> saldosPorProducto;
  final List<Producto> productos;
  final VoidCallback onAbonarGlobal;
  final String nombreCliente;

  const VistaGlobal({
    super.key,
    required this.saldoTotal,
    required this.saldosPorProducto,
    required this.productos,
    required this.onAbonarGlobal,
    required this.nombreCliente,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Center(
          child: Text(
            nombreCliente,
            style: const TextStyle(fontSize: 18, color: Colors.white70),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'Deuda Total: \$${saldoTotal.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 24,
              color: saldoTotal > 0 ? Colors.redAccent : Colors.greenAccent,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: saldosPorProducto.entries.map((entry) {
              final producto = productos.firstWhere(
                (p) => p.id == entry.key.toString(),
                orElse: () => Producto(
                  id: entry.key.toString(),
                  nombre: 'Producto ${entry.key}',
                  clienteId: '',
                  descripcion: 'Producto no encontrado',
                  fechaCreacion: '',  
                ),
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(producto.nombre, style: const TextStyle(color: Colors.white)),
                  subtitle: Text("Deuda: \$${entry.value.toStringAsFixed(2)}",
                      style: const TextStyle(color: Colors.white70)),
                  tileColor: const Color(0xFF252A3D),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
