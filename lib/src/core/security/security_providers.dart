import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'security_providers.g.dart';

@riverpod
class BiometricAuth extends _$BiometricAuth {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  FutureOr<void> build() {}

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        return false;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'الرجاء تأكيد هويتك للمتابعة',
      );
      return didAuthenticate;
    } catch (e) {
      print('Biometric auth error: $e');
      return false;
    }
  }
}
