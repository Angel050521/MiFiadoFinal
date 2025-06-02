import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/cliente.dart';
import '../models/producto.dart';

class ProductoFormScreen extends StatefulWidget {
  final Cliente cliente;

  const ProductoFormScreen({super.key, required this.cliente});

  @override
  State<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends State<ProductoFormScreen> {
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _db = DatabaseHelper.instance;

  Future<void> _guardarProducto() async {
    final nombre = _nombreController.text.trim();
    final descripcion = _descripcionController.text.trim();
    if (nombre.isEmpty) return;

    final producto = Producto(
      clienteId: widget.cliente.id!,
      nombre: nombre,
      descripcion: descripcion.isNotEmpty ? descripcion : null,
      fechaCreacion: DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now()),
    );

    await _db.insertProducto(producto);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto agregado correctamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        title: const Text("Nuevo Producto"),
        backgroundColor: const Color(0xFF1B1E2F),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _nombreController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Nombre del producto", Icons.shopping_bag),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descripcionController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Descripción (opcional)", Icons.description),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _guardarProducto,
              icon: const Icon(Icons.save),
              label: const Text("Guardar"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: const Color(0xFF0066CC),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF252A3D),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white30),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF0066CC)),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}