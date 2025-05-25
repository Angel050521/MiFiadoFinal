import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/pedido.dart';

class PedidoFormScreen extends StatefulWidget {
  final Pedido? pedido;
  const PedidoFormScreen({Key? key, this.pedido}) : super(key: key);

  @override
  State<PedidoFormScreen> createState() => _PedidoFormScreenState();
}

class _PedidoFormScreenState extends State<PedidoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _clienteCtrl;
  late TextEditingController _tituloCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _precioCtrl;
  DateTime? _fechaEntrega;
  final _db = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    final p = widget.pedido;
    _clienteCtrl = TextEditingController(text: p?.cliente ?? '');
    _tituloCtrl  = TextEditingController(text: p?.titulo  ?? '');
    _descCtrl    = TextEditingController(text: p?.descripcion ?? '');
    _precioCtrl  = TextEditingController(
        text: p?.precio != null ? p!.precio!.toStringAsFixed(2) : ''
    );
    _fechaEntrega = p?.fechaEntrega;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final nuevo = Pedido(
      id: widget.pedido?.id,
      cliente: _clienteCtrl.text.trim(),
      titulo : _tituloCtrl.text.trim(),
      descripcion: _descCtrl.text.trim(),
      fechaEntrega: _fechaEntrega,
      precio: double.tryParse(_precioCtrl.text.trim()),
      hecho: widget.pedido?.hecho ?? false,
    );
    if (widget.pedido == null) {
      await _db.insertPedido(nuevo);
    } else {
      await _db.updatePedido(nuevo);
    }
    Navigator.pop(context, true);
  }

  Future<void> _pickDate() async {
    final sel = await showDatePicker(
      context: context,
      initialDate: _fechaEntrega ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (c, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00BFFF),
            surface: Color(0xFF252A3D),
          ),
          dialogBackgroundColor: const Color(0xFF1B1E2F),
        ),
        child: child!,
      ),
    );
    if (sel != null) setState(() => _fechaEntrega = sel);
  }

  Widget _field({
    required TextEditingController ctl,
    required IconData icon,
    required String hint,
    bool requiredField = true,
    TextInputType type = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctl,
      style: const TextStyle(color: Colors.white),
      keyboardType: type,
      validator: requiredField
          ? (v) => v == null || v.trim().isEmpty ? 'Requerido' : null
          : null,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF252A3D),
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00BFFF), width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.pedido != null;
    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E2F),
        elevation: 0,
        title: Text(isEdit ? 'Editar Pedido' : 'Registrar Pedido',
            style: const TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _field(ctl: _clienteCtrl, icon: Icons.person, hint: 'Cliente'),
              const SizedBox(height: 16),
              _field(ctl: _tituloCtrl,  icon: Icons.title, hint: 'Título'),
              const SizedBox(height: 16),
              _field(ctl: _descCtrl,    icon: Icons.description, hint: 'Descripción', requiredField: false),
              const SizedBox(height: 16),
              _field(
                ctl: _precioCtrl,
                icon: Icons.attach_money,
                hint: 'Precio (opcional)',
                requiredField: false,
                type: TextInputType.number,
              ),
              const SizedBox(height: 22),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252A3D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Color(0xFF00BFFF)),
                      const SizedBox(width: 10),
                      Text(
                        _fechaEntrega == null
                            ? 'Seleccionar fecha'
                            : DateFormat('dd MMM yyyy').format(_fechaEntrega!),
                        style: TextStyle(
                          color: _fechaEntrega == null
                              ? Colors.white70
                              : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _guardar,
                child: Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BFFF),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00BFFF).withOpacity(0.6),
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
                  child: Center(
                    child: Text(
                      isEdit ? 'Actualizar Pedido' : 'Guardar Pedido',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
