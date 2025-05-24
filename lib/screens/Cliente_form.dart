import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/cliente.dart';
import '../models/producto.dart';
import '../utils/sync_helper.dart';

class ClienteFormScreen extends StatefulWidget {
  const ClienteFormScreen({Key? key}) : super(key: key);

  @override
  State<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends State<ClienteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _db = DatabaseHelper();

  Future<void> _guardarCliente() async {
    if (_formKey.currentState!.validate()) {
      final nombreNuevo = _nombreController.text.trim().toLowerCase();

      final clientesExistentes = await _db.getClientes();
      final yaExiste = clientesExistentes.any(
            (c) => c.nombre.trim().toLowerCase() == nombreNuevo,
      );

      if (yaExiste) {
        _showErrorDialog("Ya existe un cliente con ese nombre. Por favor elige otro.");
        return;
      }

      final nuevoCliente = Cliente(
        nombre: _nombreController.text.trim(),
        telefono: _telefonoController.text.trim(),
      );

      final idNuevoCliente = await _db.insertCliente(nuevoCliente);

      await _db.insertProducto(Producto(
        clienteId: idNuevoCliente,
        nombre: 'Cuenta principal',
        descripcion: 'Cuenta general del cliente',
        fechaCreacion: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      ));

      await SyncHelper.marcarPendiente();
      await SyncHelper.intentarSincronizar();

      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(context).pop(true);
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: const Color(0xFF252A3D),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.check_circle_outline, color: Color(0xFF2ECC71), size: 60),
              SizedBox(height: 16),
              Text(
                "Cliente creado exitosamente",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    ).then((value) {
      if (value == true) {
        Navigator.of(context).pop(true);
      }
    });
  }

  void _showErrorDialog(String mensaje) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF252A3D),
        title: const Text("Error", style: TextStyle(color: Colors.white)),
        content: Text(mensaje, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text("Aceptar", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(context).pop(),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        title: const Text('Registrar Cliente'),
        backgroundColor: const Color(0xFF1B1E2F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildField(_nombreController, 'Nombre completo', Icons.person,
                  customValidator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'El nombre es obligatorio';
                    return null;
                  }),
              const SizedBox(height: 12),
              _buildField(
                _telefonoController,
                'Teléfono',
                Icons.phone,
                inputType: TextInputType.phone,
                isRequired: false,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _guardarCliente,
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Guardar Cliente',
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

  Widget _buildField(
      TextEditingController controller,
      String label,
      IconData icon, {
        TextInputType inputType = TextInputType.text,
        bool isRequired = true,
        String? Function(String?)? customValidator,
      }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF252A3D),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF0066CC)),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: customValidator ??
          (isRequired
              ? (value) => (value == null || value.isEmpty) ? 'Este campo es requerido' : null
              : null),
    );
  }
}
