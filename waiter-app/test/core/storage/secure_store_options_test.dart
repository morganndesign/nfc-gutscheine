import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/storage/secure_store.dart';

/// Root cause of the endless launch screen of 1.4.1: `KeyCipherAlgorithm.AES_GCM_NoPadding`
/// is flutter_secure_storage's *biometric* mode (Keystore key with user authentication for
/// every use). On a phone with a screen lock the first access in `bootstrap` then fails or
/// waits for a prompt before the first frame. Keep the standard (RSA-wrapped) key.
void main() {
  test('Android secure storage does not use the biometric key cipher', () {
    final Map<String, String> options = PlatformSecretStore.androidOptions.toMap();
    expect(options['keyCipherAlgorithm'], 'RSA_ECB_OAEPwithSHA_256andMGF1Padding');
    expect(options['keyCipherAlgorithm'], isNot('AES_GCM_NoPadding'));
    expect(options['storageCipherAlgorithm'], 'AES_GCM_NoPadding');
  });
}
