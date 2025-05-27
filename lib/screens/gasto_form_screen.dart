import 'package:flutter/material.dart';
import '../models/gasto.dart';

class GastoFormScreen extends StatefulWidget {
  final void Function(Gasto gasto) onGuardar;
  const GastoFormScreen({super.key, required this.onGuardar});

  @override
  State<GastoFormScreen> createState() => _GastoFormScreenState();
}

class _GastoFormScreenState extends State<GastoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _conceptoCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();
  DateTime _fecha = DateTime.now();

  InputDecoration _decoration({required IconData icon, required String hint}) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: Colors.white70),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF252A3D),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF252A3D)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0066CC), width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        title: const Text('Nuevo Gasto', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1B1E2F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Concepto
              TextFormField(
                controller: _conceptoCtrl,
                style: const TextStyle(color: Colors.white),
                validator: (v) => v == null || v.isEmpty ? 'Ingrese concepto' : null,
                decoration: _decoration(icon: Icons.text_snippet, hint: 'Concepto'),
              ),
              const SizedBox(height: 16),

              // Monto
              TextFormField(
                controller: _montoCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingrese monto';
                  final d = double.tryParse(v);
                  if (d == null || d <= 0) return 'Monto inválido';
                  return null;
                },
                decoration: _decoration(icon: Icons.attach_money, hint: 'Monto'),
              ),
              const SizedBox(height: 16),

              // Fecha
              GestureDetector(
                onTap: () async {
                  final sel = await showDatePicker(
                    context: context,
                    initialDate: _fecha,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    builder: (c, child) => Theme(
                      data: ThemeData.dark().copyWith(
                        colorScheme: const ColorScheme.dark(
                          primary: Color(0xFF0066CC),
                          onPrimary: Colors.white,
                          surface: Color(0xFF252A3D),
                          onSurface: Colors.white70,
                        ),
                        dialogBackgroundColor: const Color(0xFF1B1E2F),
                      ),
                      child: child!,
                    ),
                  );
                  if (sel != null) setState(() => _fecha = sel);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252A3D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white70),
                      const SizedBox(width: 12),
                      Text(
                        '${_fecha.day}/${_fecha.month}/${_fecha.year}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Botón Guardar
              GestureDetector(
                onTap: () {
                  if (_formKey.currentState!.validate()) {
                    final gasto = Gasto(
                      concepto: _conceptoCtrl.text.trim(),
                      monto: double.parse(_montoCtrl.text.trim()),
                      fecha: _fecha,
                    );
                    widget.onGuardar(gasto);
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066CC),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0066CC).withOpacity(0.6),
                        offset: const Offset(0, 4),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Guardar Gasto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
