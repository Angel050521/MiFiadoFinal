import 'package:in_app_purchase/in_app_purchase.dart';

class InAppPurchaseService {
  static const List<String> _kIdsSuscripciones = [
    'nube100mxn',
    'premium150mxn',
  ];

  static Future<List<ProductDetails>> obtenerDetallesProductos() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      throw Exception('Tienda de compras no disponible');
    }
    final ProductDetailsResponse response =
        await InAppPurchase.instance.queryProductDetails(_kIdsSuscripciones.toSet());
    if (response.error != null) {
      throw Exception('Error al consultar productos: ${response.error!.message}');
    }
    return response.productDetails;
  }
}
