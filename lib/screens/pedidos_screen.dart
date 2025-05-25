import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/pedido.dart';
import 'pedido_form_screen.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({Key? key}) : super(key: key);

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  final _db = DatabaseHelper();
  List<Pedido> _todosLosPedidos = [];

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    final pedidos = await _db.getPedidos();
    setState(() => _todosLosPedidos = pedidos);
  }

  void _eliminarPedido(int id) async {
    await _db.eliminarPedido(id);
    _cargarPedidos();
  }

  void _marcarComoHecho(Pedido p) async {
    await _db.updatePedido(p.copyWith(hecho: true));
    _cargarPedidos();
  }

  Widget _buildCard(Pedido p) {
    return Card(
      color: const Color(0xFF252A3D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      shadowColor: Colors.black54,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        // Eliminamos el 'leading' para que no aparezca el círculo azul
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          p.titulo,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${p.cliente} • ${_etiquetaFecha(p.fechaEntrega)}',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.precio != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  '\$${p.precio!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
              onPressed: () => _marcarComoHecho(p),
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.lightBlueAccent),
              onPressed: () async {
                final modificado = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PedidoFormScreen(pedido: p),
                  ),
                );
                if (modificado == true) _cargarPedidos();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: () => _eliminarPedido(p.id!),
            ),
          ],
        ),
      ),
    );
  }


  static String _etiquetaFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin fecha';
    final hoy = DateTime.now();
    final diff = fecha.difference(hoy).inDays;
    if (diff < 0) return 'Vencido';
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    return 'En $diff días';
  }

  @override
  Widget build(BuildContext context) {
    final pendientes = _todosLosPedidos.where((p) => !p.hecho).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E2F),
        elevation: 0,
        title: const Text('Pedidos', style: TextStyle(color: Colors.white)),
      ),
      body: pendientes.isEmpty
          ? const Center(
        child: Text(
          'No hay pedidos registrados.',
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
      )
          : ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: pendientes.map(_buildCard).toList(),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF00BFFF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BFFF).withOpacity(0.6),
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () async {
            final creado = await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const PedidoFormScreen()),
            );
            if (creado == true) _cargarPedidos();
          },
          child: const Icon(Icons.add, size: 32, color: Colors.white),
        ),
      ),
    );
  }
}
