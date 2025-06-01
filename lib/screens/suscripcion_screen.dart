import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/nube_service.dart';
import 'auth_screen.dart';

class SuscripcionScreen extends StatefulWidget {
  const SuscripcionScreen({super.key});

  @override
  State<SuscripcionScreen> createState() => _SuscripcionScreenState();
}

class _SuscripcionScreenState extends State<SuscripcionScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  final Set<String> _productIds = {'nube100mxn', 'premium150mxn'};
  List<ProductDetails> _products = [];
  bool _loading = true;
  bool _userHasAccount = false;
  String? _userId;
  String? _userToken;

  @override
  void initState() {
    super.initState();
    _checkUserAccount();
    _initStoreInfo();
    // Listener de compras
    final purchaseUpdated = _iap.purchaseStream;
    purchaseUpdated.listen(_onPurchaseUpdated, onDone: () {}, onError: (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error en el proceso de compra: ${error.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    });
  }

  Future<void> _checkUserAccount() async {
    print('🔍 Iniciando verificación de cuenta de usuario...');
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Obtener todos los valores relevantes
      final userId = prefs.getString('userId');
      final userToken = prefs.getString('token');
      final userEmail = prefs.getString('userEmail');
      
      // Función auxiliar para formatear valores sensibles de forma segura
      String formatSensitive(String? value) {
        if (value == null) return 'null';
        if (value.isEmpty) return 'empty';
        try {
          final length = value.length;
          final prefix = length > 3 ? value.substring(0, 3) : value;
          return '***$prefix... (length: $length)';
        } catch (e) {
          return 'error_formatting';
        }
      }
      
      // Mostrar valores recuperados (con información sensible ofuscada)
      print('📋 Datos recuperados de SharedPreferences:');
      print('   - userId: ${formatSensitive(userId)}');
      print('   - userToken: ${formatSensitive(userToken)}');
      print('   - userEmail: $userEmail');
      
      // Verificar validez de los datos
      final hasValidUserId = userId != null && userId.isNotEmpty;
      final hasValidToken = userToken != null && userToken.isNotEmpty;
      final isAuthenticated = hasValidUserId && hasValidToken;
      
      print('🔍 Estado de autenticación:');
      print('   - userId: ${hasValidUserId ? '✅ válido' : '❌ inválido o faltante'}');
      print('   - token: ${hasValidToken ? '✅ válido' : '❌ inválido o faltante'}');
      print('   - Estado: ${isAuthenticated ? '✅ USUARIO AUTENTICADO' : '❌ USUARIO NO AUTENTICADO'}');
      
      // Si no está autenticado, intentar verificar si hay un usuario en la base de datos local
      if (!isAuthenticated) {
        print('⚠️ No se encontró una sesión activa válida');
        print('🔍 Verificando si hay un usuario en la base de datos local...');
        
        // Aquí podrías agregar lógica para verificar en la base de datos local
        // si tienes un sistema de autenticación local
      }
      
      // Actualizar el estado con los valores obtenidos
      if (mounted) {
        setState(() {
          _userHasAccount = isAuthenticated;
          _userId = hasValidUserId ? userId : null;
          _userToken = hasValidToken ? userToken : null;
        });
      }
      
      return;
      
    } catch (e, stackTrace) {
      print('❌ Error en _checkUserAccount: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _userHasAccount = false;
          _userId = null;
          _userToken = null;
        });
      }
    }
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _iap.isAvailable();
    if (!isAvailable) {
      setState(() => _loading = false);
      return;
    }
    final ProductDetailsResponse response =
        await _iap.queryProductDetails(_productIds);
    if (response.error == null && response.productDetails.isNotEmpty) {
      setState(() {
        _products = response.productDetails;
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _comprar(ProductDetails producto) async {
    print('🛒 Iniciando proceso de compra para: ${producto.id}');
    
    // Verificar autenticación
    await _checkUserAccount();
    
    // Si no hay usuario autenticado, mostrar diálogo de error detallado
    if (!_userHasAccount || _userId == null || _userToken == null) {
      print('❌ Usuario no autenticado. Mostrando diálogo de error...');
      
      if (!mounted) return;
      
      // Mostrar diálogo detallado explicando el problema
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Text('Cuenta requerida'),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Para realizar una compra, necesitas iniciar sesión o crear una cuenta.'),
              SizedBox(height: 12),
              Text('¿Deseas ir a la pantalla de inicio de sesión ahora?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Ahora no'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ir a inicio de sesión'),
            ),
          ],
        ),
      );
      
      // Si el usuario quiere ir al inicio de sesión
      if (result == true) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
      
      return;
    }
    
    print('✅ Usuario autenticado. Mostrando confirmación de compra...');
    
    // Mostrar diálogo de confirmación con el estilo de la app
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).dialogBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono de confirmación
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_cart_checkout_rounded,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              
              // Título
              Text(
                'Confirmar compra',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Contenido
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estás a punto de suscribirte a:',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      producto.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Precio: ${producto.price}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'El pago se cargará a tu método de pago de Google Play.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Botones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Text(
                        'Cancelar',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Confirmar compra'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm != true) {
      print('❌ Compra cancelada por el usuario');
      return;
    }

    print('🔄 Procesando la compra...');
    setState(() => _loading = true);

    try {
      print('📦 Creando parámetros de compra...');
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: producto,
      );

      // Iniciar el flujo de compra
      print('🔄 Iniciando flujo de compra en Google Play...');
      if (_products[0].id == producto.id) {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
      
      print('✅ Flujo de compra iniciado correctamente');
    } catch (e, stackTrace) {
      print('❌ Error al procesar la compra: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar la compra: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Maneja compras exitosas
  void _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    print('🔔 Evento de compra recibido: ${purchases.length} compras');
    
    try {
      for (final PurchaseDetails purchase in purchases) {
        print('🔄 Procesando compra: ${purchase.productID}, estado: ${purchase.status}');
        
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          try {
            // 1. Guardar el plan en SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('plan_activo', purchase.productID);
            print('✅ Plan guardado localmente: ${purchase.productID}');

            // 2. Finalizar la compra si es necesario
            if (purchase.pendingCompletePurchase) {
              print('⏳ Completando compra pendiente...');
              await _iap.completePurchase(purchase);
              print('✅ Compra completada');
            }

            // 3. Verificar si tenemos los datos de usuario necesarios
            if (_userId == null || _userToken == null) {
              print('⚠️ No hay datos de usuario disponibles. Intentando recuperar...');
              await _checkUserAccount(); // Actualizar los datos de usuario
              
              if (_userId == null || _userToken == null) {
                print('❌ No se pudo obtener la información del usuario');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: No se pudo verificar tu cuenta. Por favor, cierra sesión y vuelve a iniciar.'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 5),
                    ),
                  );
                }
                return;
              }
            }

            // 4. Verificar que tengamos un ID de usuario válido antes de continuar
            if (_userId == null || _userId!.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Error: No se pudo identificar tu cuenta. Inicia sesión de nuevo.'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
              print('❌ Error: ID de usuario no disponible');
              return;
            }

            // 5. Actualizar el plan en Cloudflare
            print('☁️ Actualizando plan en la nube...');
            print('   - User ID: $_userId');
            print('   - Plan: ${purchase.productID}');
            
            final result = await NubeService.actualizarPlan(
              userId: _userId!,
              plan: purchase.productID,
            );
            
            if (mounted) {
              if (result['success'] == true) {
                print('✅ Plan actualizado en la nube exitosamente');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('¡Suscripción ${purchase.productID} activada! Sincronización exitosa.'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 5),
                  ),
                );
              } else {
                // Manejar específicamente el error 401 (No autorizado)
                if (result['statusCode'] == 401) {
                  print('🔑 Error de autenticación (401). Token expirado o inválido.');
                  
                  // Mostrar diálogo para volver a autenticar
                  final relogin = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: const Text('Sesión expirada'),
                      content: const Text('Tu sesión ha expirado. ¿Deseas iniciar sesión de nuevo?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Ahora no'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Iniciar sesión'),
                        ),
                      ],
                    ),
                  );
                  
                  if (relogin == true && mounted) {
                    // Navegar a la pantalla de autenticación
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const AuthScreen()),
                    );
                  }
                } else {
                  // Otros errores
                  print('❌ Error al actualizar en la nube: ${result['error']}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al actualizar en la nube: ${result['error'] ?? 'Error desconocido'}'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'Reintentar',
                        textColor: Colors.white,
                        onPressed: () async {
                          print('🔄 Reintentando actualización del plan...');
                          // Verificar nuevamente la autenticación antes de reintentar
                          await _checkUserAccount();
                          
                          if (_userId == null || _userToken == null) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No se pudo verificar tu cuenta. Por favor, inicia sesión de nuevo.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                            return;
                          }
                          
                          final retryResult = await NubeService.actualizarPlan(
                            userId: _userId!,
                            plan: purchase.productID,
                          );
                          
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  retryResult['success']
                                    ? '¡Sincronización exitosa!'
                                    : 'Error: ${retryResult['error']}.',
                                ),
                                backgroundColor: retryResult['success'] ? Colors.green : Colors.orange,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                }
              }
            }
          } catch (e, stackTrace) {
            print('❌ Error inesperado en _onPurchaseUpdated: $e');
            print('Stack trace: $stackTrace');
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Error al procesar la compra. Por favor, verifica tu conexión e intenta de nuevo.'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'Cerrar',
                    textColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                  ),
                ),
              );
            }
          }
        } else if (purchase.status == PurchaseStatus.error) {
          print('❌ Error en la compra: ${purchase.error}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error en la compra: ${purchase.error?.message ?? 'Error desconocido'}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
      
      // Actualizar el estado de carga
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error inesperado en el bucle de compras: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _loading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error inesperado al procesar la compra. Por favor, inténtalo de nuevo.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }



  void _restaurarCompras() {
    _iap.restorePurchases();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Buscando compras anteriores...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E2F),
        title: const Text('Planes de Suscripción'),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore, color: Colors.white),
            tooltip: "Restaurar compras",
            onPressed: _restaurarCompras,
          ),
        ],
      ),
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
                      filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        width: constraints.maxWidth > 600 ? 600 : double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 40, horizontal: 24),
                        child: _loading
                            ? const Center(
                                child:
                                    CircularProgressIndicator(color: Colors.white))
                            : _products.isEmpty
                                ? const Text(
                                    'No se encontraron productos disponibles.',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 16),
                                    textAlign: TextAlign.center,
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: _products
                                        .map((producto) => Container(
                                              margin:
                                                  const EdgeInsets.only(bottom: 24),
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF252A3D)
                                                    .withOpacity(0.9),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.3),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    producto.title,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 18,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    producto.description,
                                                    style: const TextStyle(
                                                        color: Colors.white70),
                                                  ),
                                                  const SizedBox(height: 16),
                                                  GestureDetector(
                                                    onTap: () => _comprar(producto),
                                                    child: Container(
                                                      width: double.infinity,
                                                      height: 48,
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                            0xFF00BFFF),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                12),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: const Color(
                                                                    0xFF00BFFF)
                                                                .withOpacity(0.6),
                                                            offset:
                                                                const Offset(0, 4),
                                                            blurRadius: 12,
                                                            spreadRadius: 1,
                                                          ),
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(0.3),
                                                            offset:
                                                                const Offset(0, 2),
                                                            blurRadius: 6,
                                                          ),
                                                        ],
                                                      ),
                                                      child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          const Icon(Icons.lock_open,
                                                              color: Colors.white),
                                                          const SizedBox(width: 10),
                                                          Text(
                                                            'Suscribirme por ${producto.price}',
                                                            style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                ],
                                              ),
                                            ))
                                        .toList(),
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
}
