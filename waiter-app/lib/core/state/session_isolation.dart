import '../storage/secure_store.dart';
import '../storage/settings_store.dart';

/// Keys of the sign-in in secure storage (see `SessionController`).
const List<String> sessionSecretKeys = <String>['token', 'profile'];

/// Forgets the stored sign-in when it belongs to another server than
/// [apiBaseUrl], then records [apiBaseUrl] as the session's server. Returns
/// whether a sign-in was dropped.
Future<bool> forgetSessionOfOtherServer({
  required SettingsStore settings,
  required SecretStore secrets,
  required String apiBaseUrl,
}) async {
  final String? previous = settings.sessionServer;
  if (previous == apiBaseUrl) return false;
  settings.sessionServer = apiBaseUrl;
  if (previous == null) return false;
  for (final String key in sessionSecretKeys) {
    await secrets.delete(key);
  }
  return true;
}
