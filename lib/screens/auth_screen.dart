import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../utils/device_util.dart';
import '../services/cloudflare_service.dart';
import '../screens/home_screen.dart';

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  
  const AuthScreen({super.key, this.isLogin = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _db = DatabaseHelper.instance;

  bool _isLogin = true;
  bool _isLoading = false;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
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
      setState(() => _isLoading = true);
      
      final nombre = _nombreController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      try {
        if (_isLogin) {
          // Iniciar sesión con Cloudflare
          final usuario = await CloudflareService.loginUser(
            email: email,
            password: password,
          );
          
          if (usuario != null) {
            _showMensaje("Bienvenido, ${usuario['nombre']} 👋");
            
            // También guarda en SQLite para tener una copia local
            await _db.loginUsuario(email, password);
            
            // Navegar a la pantalla principal
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen())
              );
            }
          } else {
            _showError("Correo o contraseña incorrectos");
          }
        } else {
          // Registrar con Cloudflare
          final usuario = await CloudflareService.registerUser(
            nombre: nombre,
            email: email,
            password: password,
          );
          
          if (usuario != null) {
            // También guarda en SQLite
            await _db.insertUsuario(nombre, email, password);
            
            _showMensaje("Cuenta creada correctamente 🎉");
            
            // Navegar a la pantalla principal
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeScreen())
              );
            }
          } else {
            _showError("Error al crear la cuenta. Intenta con otro correo.");
          }
        }
      } catch (e) {
        _showError("Error de conexión: $e");
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
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
                                if (!_isLogin)
                                  _buildField(_nombreController, 'Nombre completo'),
                                const SizedBox(height: 12),
                                _buildField(
                                  _emailController,
                                  'Correo electrónico',
                                  tipo: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 12),
                                _buildField(_passwordController, 'Contraseña', obscure: true),
                                const SizedBox(height: 24),
                                _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Color(0xFF00BFFF),
                                      )
                                    : GestureDetector(
                                        onTap: _submit,
                                        child: Container(
                                          width: double.infinity,
                                          height: 56,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFF00BFFF),
                                                Color(0xFF0080FF)
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF00BFFF).withOpacity(0.4),
                                                offset: const Offset(0, 4),
                                                blurRadius: 12,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              _isLogin ? 'Iniciar sesión' : 'Crear cuenta',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: _toggleMode,
                                  child: Text(
                                    _isLogin
                                        ? '¿No tienes cuenta? Regístrate'
                                        : '¿Ya tienes cuenta? Inicia sesión',
                                    style: const TextStyle(
                                      color: Color(0xFF00BFFF),
                                    ),
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

  Widget _buildField(
    TextEditingController controller,
    String label, {
    TextInputType tipo = TextInputType.text,
    bool obscure = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: tipo,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00BFFF)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        errorStyle: const TextStyle(color: Colors.red),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Este campo es requerido';
        }
        if (tipo == TextInputType.emailAddress && !value.contains('@')) {
          return 'Ingresa un correo válido';
        }
        if (obscure && value.length < 6) {
          return 'La contraseña debe tener al menos 6 caracteres';
        }
        return null;
      },
    );
  }
}
