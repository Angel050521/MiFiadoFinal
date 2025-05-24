import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkUtil {
  static Future<bool> hayConexion() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
}
