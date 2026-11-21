import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (defaultTargetPlatform == TargetPlatform.windows) return true;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    if (!await isAvailable()) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock your MindSpeak session',
        // Windows Hello does not let the plugin select biometrics separately;
        // on mobile, require an enrolled biometric specifically.
        biometricOnly: defaultTargetPlatform != TargetPlatform.windows,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
