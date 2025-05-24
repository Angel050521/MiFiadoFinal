import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class DeviceUtil {
  static Future<String> obtenerId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo;
        return info.id?.isNotEmpty == true
            ? info.id!
            : (info.androidId ?? 'unknown-android');
      } else if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo;
        return info.identifierForVendor ?? 'unknown-ios';
      } else {
        return 'unknown-device';
      }
    } catch (e) {
      print('❌ Error al obtener el deviceId: $e');
      return 'device-error';
    }
  }
}
