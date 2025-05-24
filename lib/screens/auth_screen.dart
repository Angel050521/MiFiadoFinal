import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../utils/device_util.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _db = DatabaseHelper();

  bool _isLogin = true;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _cargarDeviceId();
  }

  Future<void> _cargarDeviceId() async {
    _deviceId = await DeviceUtil.obtenerId();
  }

  void _toggleMode() {
    setState(() => _isLogin = !_isLogin);
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final nombre = _nombreController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final pass = _passwordController.text.trim();

      final prefs = await SharedPreferences.getInstance();

      if (_isLogin) {
        final usuario = await _db.loginUsuario(email, pass);
        if (usuario != null) {
          final plan = usuario['plan'] ?? 'gratis';
          final userId = usuario['id'].toString();
          final token = pass;

          // Paso nuevo: validar en la nube
          if (plan == 'nube') {
            final permitido = await NubeService.validarODeseaMigrar(
              userId: userId,
              token: token,
              deviceId: _deviceId ?? 'unknown',
            );

            if (!permitido) {
              final migrar = await _mostrarDialogoMigrar();
              if (migrar) {
                await NubeService.actualizarDevice(
                  userId: userId,
                  token: token,
                  deviceId: _deviceId ?? 'unknown',
                );
              } else {
                _showError("No se puede iniciar sesión desde este dispositivo.");
                return;
              }
            }
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('userId', usuario['id'] as int);
          await prefs.setString('plan', plan);
          await prefs.setString('token', token);
          await prefs.setString('userEmail', email);
          await prefs.setString('deviceId_$email', _deviceId ?? '');

          _showMensaje("Bienvenido, ${usuario['nombre']} 👋");
        } else {
          _showError("Correo o contraseña incorrectos");
        }
      }

        await _db.insertUsuario(nombre, email, pass);
        final nuevo = await _db.loginUsuario(email, pass);
        if (nuevo != null) {
          await prefs.setInt('userId', nuevo['id'] as int);
          await prefs.setString('plan', 'gratis');
          await prefs.setString('token', pass);
          await prefs.setString('userEmail', email);
          await prefs.setString('deviceId_$email', _deviceId ?? '');
        }

        _showMensaje("Cuenta creada correctamente 🎉");
        setState(() => _isLogin = true);
      }
    }
  }

  Future<bool> _mostrarDialogoMigrar() async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF252A3D),
        title: const Text("¿Cambiar de dispositivo?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Tu cuenta está en otro celular. ¿Deseas migrarla a este dispositivo?\n\nEsto cerrará la sesión en el anterior.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Migrar", style: TextStyle(color: Color(0xFF00BFFF))),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _showMensaje(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFF00BFFF)),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B1E2F), Color(0xFF0D0F1A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: constraints.maxWidth > 600 ? 500 : double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                if (!_isLogin) _buildField(_nombreController, 'Nombre completo'),
                                const SizedBox(height: 12),
                                _buildField(_emailController, 'Correo electrónico',
                                    tipo: TextInputType.emailAddress),
                                const SizedBox(height: 12),
                                _buildField(_passwordController, 'Contraseña', obscure: true),
                                const SizedBox(height: 24),
                                GestureDetector(
                                  onTap: _submit,
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
                                    child: const Center(
                                      child: Text(
                                        'Entrar',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: _toggleMode,
                                  child: Text(
                                    _isLogin
                                        ? '¿No tienes cuenta? Crea una'
                                        : '¿Ya tienes cuenta? Inicia sesión',
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label,
      {bool obscure = false, TextInputType tipo = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: tipo,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: (val) => (val == null || val.trim().isEmpty) ? 'Campo obligatorio' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF252A3D),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF00BFFF)),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
