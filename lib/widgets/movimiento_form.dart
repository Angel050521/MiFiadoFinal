import 'package:flutter/material.dart';

class MovimientoForm extends StatelessWidget {
  final TextEditingController montoController;
  final TextEditingController descController;
  final String tipo;
  final ValueChanged<String?> onTipoChanged;
  final VoidCallback onGuardar;

  const MovimientoForm({
    super.key,
    required this.montoController,
    required this.descController,
    required this.tipo,
    required this.onTipoChanged,
    required this.onGuardar,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Agregar Movimiento",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: montoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Monto",
              labelStyle: TextStyle(color: Colors.white70),
              prefixIcon: Icon(Icons.attach_money, color: Colors.white70),
              filled: true,
              fillColor: Color(0xFF1B1E2F),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0066CC)),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Descripción",
              labelStyle: TextStyle(color: Colors.white70),
              prefixIcon: Icon(Icons.description, color: Colors.white70),
              filled: true,
              fillColor: Color(0xFF1B1E2F),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0066CC)),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: tipo,
            items: const [
              DropdownMenuItem(value: "cargo", child: Text("Cargo")),
              DropdownMenuItem(value: "abono", child: Text("Abono")),
            ],
            onChanged: onTipoChanged,
            dropdownColor: const Color(0xFF1B1E2F),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Tipo de Movimiento",
              labelStyle: TextStyle(color: Colors.white70),
              prefixIcon: Icon(Icons.swap_horiz, color: Colors.white70),
              filled: true,
              fillColor: Color(0xFF1B1E2F),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white30),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF0066CC)),
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Guardar"),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: const Color(0xFF0066CC),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onGuardar,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
