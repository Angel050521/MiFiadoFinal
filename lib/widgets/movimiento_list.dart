import 'package:flutter/material.dart';
import '../models/movimiento.dart';

class MovimientoList extends StatelessWidget {
  final List<Movimiento> movimientos;

  const MovimientoList({super.key, required this.movimientos});

  @override
  Widget build(BuildContext context) {
    if (movimientos.isEmpty) {
      return const Center(
        child: Text("No hay movimientos aún.", style: TextStyle(color: Colors.white70)),
      );
    }
    return ListView.builder(
      itemCount: movimientos.length,
      itemBuilder: (context, index) {
        final mov = movimientos[index];
        return Card(
          color: const Color(0xFF252A3D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              mov.tipo == 'cargo' ? Icons.trending_up : Icons.trending_down,
              color: mov.tipo == 'cargo' ? Colors.redAccent : Colors.greenAccent,
            ),
            title: Text(
              '${mov.tipo == 'cargo' ? '+' : '-'}\$${mov.monto.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${mov.descripcion}\n${mov.fecha}',
              style: const TextStyle(color: Colors.white70),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
