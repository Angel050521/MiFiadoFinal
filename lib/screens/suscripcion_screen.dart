import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _initStoreInfo();
    // Listener de compras
    final purchaseUpdated = _iap.purchaseStream;
    purchaseUpdated.listen(_onPurchaseUpdated, onDone: () {}, onError: (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error en el proceso de compra')),
      );
    });
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

  void _comprar(ProductDetails producto) {
    final PurchaseParam compra = PurchaseParam(productDetails: producto);
    _iap.buyNonConsumable(purchaseParam: compra);
  }

  // Maneja compras exitosas
  void _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Guarda el plan comprado
        final prefs = await SharedPreferences.getInstance();
        prefs.setString('plan_activo', purchase.productID);

        // Finaliza la compra si es necesario
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('¡Suscripción activada para ${purchase.productID}!'),
            ),
          );
        }
      }
      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error en la compra')),
          );
        }
      }
    }
  }

  void _restaurarCompras() {
    _iap.restorePurchases();
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
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
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
