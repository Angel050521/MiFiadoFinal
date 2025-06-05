import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/pedido.dart';
import '../utils/sync_helper.dart';

class PedidoFormScreen extends StatefulWidget {
  final Pedido? pedido;
  const PedidoFormScreen({Key? key, this.pedido}) : super(key: key);

  @override
  State<PedidoFormScreen> createState() => _PedidoFormScreenState();
}

class _PedidoFormScreenState extends State<PedidoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _clienteCtrl;
  late TextEditingController _telefonoCtrl;  // 1) controlador teléfono
  late TextEditingController _tituloCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _precioCtrl;

  DateTime? _fechaEntrega;
  TimeOfDay? _horaEntrega;
  final _db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    final p = widget.pedido;
    _clienteCtrl  = TextEditingController(text: p?.cliente ?? '');
    _telefonoCtrl = TextEditingController(text: p?.telefono ?? '');  // inicializa teléfono
    _tituloCtrl   = TextEditingController(text: p?.titulo ?? '');
    _descCtrl     = TextEditingController(text: p?.descripcion ?? '');
    _precioCtrl   = TextEditingController(
      text: p?.precio != null ? p!.precio!.toStringAsFixed(2) : '',
    );

    _fechaEntrega = p?.fechaEntrega;
    if (_fechaEntrega != null) {
      _horaEntrega = TimeOfDay.fromDateTime(_fechaEntrega!);
    }
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
            onPrimary: Colors.white,
            surface: Color(0xFF252A3D),
            onSurface: Colors.white70,
          ),
          dialogBackgroundColor: const Color(0xFF1B1E2F),
        ),
        child: child!,
      ),
    );
    if (sel != null) setState(() => _fechaEntrega = sel);
  }

  Future<void> _pickTime() async {
    final sel = await showTimePicker(
      context: context,
      initialTime: _horaEntrega ?? TimeOfDay.now(),
      builder: (c, child) => Theme(
        data: ThemeData.dark().copyWith(
          timePickerTheme: const TimePickerThemeData(
            hourMinuteColor: Color(0xFF00BFFF),
            hourMinuteTextColor: Colors.white,
            dayPeriodColor: Color(0xFF00BFFF),
            dayPeriodTextColor: Colors.white,
            dialBackgroundColor: Color(0xFF252A3D),
            dialHandColor: Color(0xFF00BFFF),
          ),
        ),
        child: child!,
      ),
    );
    if (sel != null) setState(() => _horaEntrega = sel);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      print('⚠️ [PEDIDO] Validación del formulario fallida');
      return;
    }

    print('🔄 [PEDIDO] Iniciando proceso de guardado de pedido');

    DateTime? fechaFinal;
    if (_fechaEntrega != null) {
      final hora = _horaEntrega ?? const TimeOfDay(hour: 0, minute: 0);
      fechaFinal = DateTime(
        _fechaEntrega!.year,
        _fechaEntrega!.month,
        _fechaEntrega!.day,
        hora.hour,
        hora.minute,
      );
    }

    print('📝 [PEDIDO] Creando objeto Pedido con los datos del formulario:');
    print('   - Cliente: ${_clienteCtrl.text}');
    print('   - Teléfono: ${_telefonoCtrl.text}');
    print('   - Título: ${_tituloCtrl.text}');
    print('   - Descripción: ${_descCtrl.text}');
    print('   - Precio: ${_precioCtrl.text}');
    print('   - Fecha entrega: $fechaFinal');

    final nuevo = Pedido(
      id: widget.pedido?.id,
      cliente: _clienteCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim().isEmpty
          ? null
          : _telefonoCtrl.text.trim(),          // 3) incluye teléfono
      titulo: _tituloCtrl.text.trim(),
      descripcion: _descCtrl.text.trim(),
      fechaEntrega: fechaFinal,
      precio: double.tryParse(_precioCtrl.text.trim()),
      hecho: widget.pedido?.hecho ?? false,
    );

    if (widget.pedido == null) {
      print('➕ [PEDIDO] Insertando nuevo pedido en la base de datos local');
      final id = await _db.insertPedido(nuevo);
        print('✅ [PEDIDO] Pedido insertado con éxito. ID asignado: $id');
    } else {
      print('🔄 [PEDIDO] Actualizando pedido existente ID: ${nuevo.id}');
      final rowsAffected = await _db.updatePedido(nuevo);
      print('✅ [PEDIDO] Pedido actualizado. Filas afectadas: $rowsAffected');
    }

    // Marcar como pendiente de sincronización
    print('🔄 [SINCRONIZAR] Marcando sincronización como pendiente');
    await SyncHelper.marcarPendiente();
    
    // Intentar sincronizar si hay conexión
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    final token = prefs.getString('token');
    
    if (userId != null && token != null) {
      print('🔄 [SINCRONIZAR] Intentando sincronizar con la nube...');
      try {
        await SyncHelper.sincronizarSiConectado(userId: userId, token: token);
        print('✅ [SINCRONIZAR] Sincronización completada exitosamente');
      } catch (e) {
        print('⚠️ [SINCRONIZAR] Error durante la sincronización: $e');
        // No hacemos nada, la sincronización se intentará en el próximo inicio
      }
    }

    print('🏁 [PEDIDO] Guardado completado, cerrando formulario');
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

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
        borderSide: const BorderSide(color: Color(0xFF00BFFF), width: 2),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        title: Text(
          widget.pedido == null ? 'Nuevo Pedido' : 'Editar Pedido',
          style: const TextStyle(color: Colors.white),
        ),
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
              TextFormField(
                controller: _clienteCtrl,
                style: const TextStyle(color: Colors.white),
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Requerido' : null,
                decoration: _decoration(
                    icon: Icons.person, hint: 'Cliente'),
              ),
              const SizedBox(height: 12),

              // 2) campo Teléfono
              TextFormField(
                controller: _telefonoCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: _decoration(
                    icon: Icons.phone, hint: 'Teléfono (opcional)'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _tituloCtrl,
                style: const TextStyle(color: Colors.white),
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Requerido' : null,
                decoration:
                _decoration(icon: Icons.title, hint: 'Título'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _descCtrl,
                style: const TextStyle(color: Colors.white),
                validator: (v) =>
                v == null || v.trim().isEmpty ? 'Requerido' : null,
                decoration: _decoration(
                    icon: Icons.description, hint: 'Descripción'),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _precioCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                validator: null,
                decoration: _decoration(
                    icon: Icons.attach_money,
                    hint: 'Precio (opcional)'),
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252A3D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _fechaEntrega == null
                        ? 'Seleccionar fecha'
                        : DateFormat('dd MMM yyyy').format(_fechaEntrega!),
                    style: TextStyle(
                      color: _fechaEntrega == null
                          ? Colors.white70
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              GestureDetector(
                onTap: _pickTime,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252A3D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _horaEntrega == null
                        ? 'Seleccionar hora'
                        : _horaEntrega!.format(context),
                    style: TextStyle(
                      color: _horaEntrega == null
                          ? Colors.white70
                          : Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Guardar Pedido',
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