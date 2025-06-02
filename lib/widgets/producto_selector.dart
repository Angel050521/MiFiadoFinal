import 'package:flutter/material.dart';
import '../models/Producto.dart';

class ProductoSelector extends StatelessWidget {
  final List<Producto> productos;
  final Producto? productoSeleccionado;
  final ValueChanged<Producto?> onProductoChanged;
  final VoidCallback onAgregarProducto;

  const ProductoSelector({
    super.key,
    required this.productos,
    required this.productoSeleccionado,
    required this.onProductoChanged,
    required this.onAgregarProducto,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<Producto>(
            value: productoSeleccionado,
            dropdownColor: const Color(0xFF252A3D),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: "Seleccionar producto",
              labelStyle: const TextStyle(color: Colors.white70),
              prefixIcon: const Icon(Icons.shopping_bag, color: Colors.white70),
              filled: true,
              fillColor: const Color(0xFF1B1E2F),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Color(0xFF0066CC)),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: productos
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p.nombre, style: const TextStyle(color: Colors.white)),
                    ))
                .toList(),
            onChanged: onProductoChanged,
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.add_circle, color: Colors.white),
          tooltip: "Agregar producto",
          onPressed: onAgregarProducto,
        )
      ],
    );
  }
}
