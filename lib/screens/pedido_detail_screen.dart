import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/pedido.dart';
import 'pedido_form_screen.dart';

class PedidoDetailScreen extends StatelessWidget {
  final Pedido pedido;
  const PedidoDetailScreen({Key? key, required this.pedido}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateLabel = pedido.fechaEntrega != null
        ? DateFormat.yMMMd().add_jm().format(pedido.fechaEntrega!)
        : 'Sin fecha';

    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E2F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Detalle de Pedido',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField('Cliente', pedido.cliente),
            const SizedBox(height: 16),
            _buildField('Numero de cliente', pedido.telefono ?? ''),
            const SizedBox(height: 16),
            _buildField('Título', pedido.titulo),
            const SizedBox(height: 16),
            _buildField('Descripción', pedido.descripcion),
            const SizedBox(height: 16),
            _buildField('Fecha de entrega', dateLabel),
            if (pedido.precio != null) ...[
              const SizedBox(height: 16),
              _buildField('Precio', '\$${pedido.precio!.toStringAsFixed(2)}'),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: const Color(0xFF1B1E2F),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          child: GestureDetector(
            onTap: () async {
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => PedidoFormScreen(pedido: pedido),
                ),
              );
              if (ok == true) Navigator.pop(context, pedido);
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF00BFFF),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00BFFF).withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Editar Pedido',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
