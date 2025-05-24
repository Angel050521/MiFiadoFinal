import 'package:connectivity_plus/connectivity_plus.dart';

class ConexionService {
  static Future<bool> hayConexion() async {
    final resultado = await Connectivity().checkConnectivity();
    return resultado != ConnectivityResult.none;
  }
}
