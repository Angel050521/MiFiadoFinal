import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final _db = DatabaseHelper.instance;

  Future<void> _guardarCliente() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ [ERROR] Validación del formulario fallida');
      return;
    }
    
    try {
      print('🔄 [DEBUG] Iniciando guardado de cliente');
      print('   - Nombre: ${_nombreController.text.trim()}');
      print('   - Teléfono: ${_telefonoController.text.trim()}');
      
      // Verificar si el cliente ya existe
      final nombreNuevo = _nombreController.text.trim().toLowerCase();
      print('🔍 [DEBUG] Verificando si el cliente ya existe...');
      
      try {
        final clientesExistentes = await _db.getClientes();
        print('   - Clientes existentes: ${clientesExistentes.length}');
        
        final yaExiste = clientesExistentes.any(
          (c) => c.nombre.trim().toLowerCase() == nombreNuevo,
        );

        if (yaExiste) {
          print('⚠️ [WARNING] Ya existe un cliente con ese nombre');
          if (mounted) {
            _showErrorDialog("Ya existe un cliente con ese nombre. Por favor elige otro.");
          }
          return;
        }
      } catch (e) {
        print('⚠️ [WARNING] Error al verificar clientes existentes: $e');
        // Continuar con el guardado a pesar del error de verificación
      }

      // Guardar el cliente localmente
      print('💾 [DEBUG] Guardando cliente en la base de datos local...');
      final nuevoCliente = Cliente(
        nombre: _nombreController.text.trim(),
        telefono: _telefonoController.text.trim(),
      );
      
      final idNuevoCliente = await _db.insertCliente(nuevoCliente);
      print('✅ [DEBUG] Cliente guardado con ID: $idNuevoCliente');

      // Crear la cuenta principal
      print('💾 [DEBUG] Creando cuenta principal...');
      try {
        await _db.insertProducto(Producto(
          clienteId: idNuevoCliente.toString(),
          nombre: 'Cuenta principal',
          descripcion: 'Cuenta general del cliente',
          fechaCreacion: DateFormat('yyyy-MM-dd').format(DateTime.now()),
        ));
        print('✅ [DEBUG] Cuenta principal creada');
      } catch (e) {
        print('⚠️ [WARNING] Error al crear la cuenta principal: $e');
        // Continuar a pesar del error en la creación de la cuenta
      }

      // Verificar el plan del usuario antes de marcar para sincronización
      final prefs = await SharedPreferences.getInstance();
      final plan = prefs.getString('plan') ?? '';
      final esPlanValido = plan == 'nube100mxn' || plan == 'premium150mxn';
      
      print('🔍 [DEBUG] Verificando plan del usuario:');
      print('   - Plan actual: $plan');
      print('   - Plan válido para sincronización: $esPlanValido');
      
      if (esPlanValido) {
        // Marcar como pendiente de sincronizar solo si el plan es válido
        print('🔄 [DEBUG] Marcando como pendiente de sincronización...');
        await SyncHelper.marcarPendiente();
        
        // Actualizar la hora de la última sincronización
        final ahora = DateTime.now();
        final fechaFormateada = '${ahora.day}/${ahora.month}/${ahora.year} ${ahora.hour}:${ahora.minute.toString().padLeft(2, '0')}';
        await prefs.setString('last_sync', ahora.toIso8601String());
        
        // Intentar sincronizar en segundo plano
        print('🔄 [DEBUG] Iniciando sincronización en segundo plano...');
        _sincronizarEnSegundoPlano();
      } else {
        print('ℹ️ [INFO] Plan actual no permite sincronización. Omitiendo sincronización.');
      }
      
      // Mostrar mensaje de éxito
      if (mounted) {
        print('✅ [DEBUG] Mostrando mensaje de éxito');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente guardado correctamente'),
            duration: Duration(seconds: 3),
          ),
        );
        
        // Cerrar el teclado si está abierto
        FocusScope.of(context).unfocus();
      }

      // Mostrar diálogo de éxito
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e, stackTrace) {
      print('❌ [ERROR] Error en _guardarCliente: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        _showErrorDialog('Error al guardar el cliente: $e');
      }
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
            onPressed: () => Navigator.pop(context),
            child: const Text("Aceptar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _sincronizarEnSegundoPlano() async {
    print('🔄 [DEBUG] Iniciando sincronización en segundo plano...');
    try {
      print('   - Llamando a SyncHelper.intentarSincronizar()');
      await SyncHelper.intentarSincronizar();
      print('✅ [DEBUG] Sincronización completada exitosamente');
      
      // Si llegamos aquí, la sincronización fue exitosa
      if (mounted) {
        print('   - Mostrando mensaje de éxito');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Datos sincronizados correctamente'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      // La sincronización falló
      print('❌ [ERROR] Error al sincronizar en segundo plano: $e');
      print('Stack trace: $stackTrace');
      
      // Mostrar mensaje de error solo en desarrollo
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al sincronizar: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      print('🔚 [DEBUG] Finalizada sincronización en segundo plano');
    }
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
