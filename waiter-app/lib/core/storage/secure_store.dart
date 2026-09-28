import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key-value contract so the stores can be tested without a platform.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Keychain (iOS: after first unlock, this device only — no iCloud sync, not in
/// backups) and Android Keystore-backed AES-GCM (09 §7.5).
///
/// Android uses the plugin's standard mode: data encrypted with AES-GCM, the
/// AES key wrapped by an RSA key in the Android Keystore. It must **not** use
/// `KeyCipherAlgorithm.AES_GCM_NoPadding`: in flutter_secure_storage 10+ that
/// is the biometric mode — the Keystore key then requires user authentication
/// for every use, so on any phone with a screen lock the very first access
/// (in `bootstrap`, before the first frame) fails ("At least one fingerprint
/// must be enrolled…") or waits for a fingerprint prompt, and the app never
/// leaves the launch screen. The token is never gated by biometrics
/// (09 §7.6); the app's biometric unlock is a UI lock.
class PlatformSecretStore implements SecretStore {
  PlatformSecretStore() : _storage = const FlutterSecureStorage(iOptions: iosOptions, aOptions: androidOptions);

  /// Standard (non-biometric) mode; guarded by a test, see the class comment.
  static const AndroidOptions androidOptions = AndroidOptions();

  static const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// In-memory implementation for tests.
class MemorySecretStore implements SecretStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<void> deleteAll() async => values.clear();
}
