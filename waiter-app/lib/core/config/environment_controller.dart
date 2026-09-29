import 'package:flutter/foundation.dart';

import '../storage/settings_store.dart';
import 'environment.dart';

/// The environment in use: the build configuration plus, in development and
/// staging builds, the server chosen in the app (stored in [SettingsStore]).
/// Listeners (API client, card-link parser) follow every change.
class EnvironmentController extends ChangeNotifier {
  EnvironmentController({required this.build, required SettingsStore settings})
      : _settings = settings,
        _current = _apply(build, build.allowsServerOverride ? settings.apiServerOverride : null);

  /// As compiled into the app.
  final AppEnvironment build;
  final SettingsStore _settings;
  AppEnvironment _current;

  AppEnvironment get current => _current;

  /// Points the app at [raw] (normalised, `/api/v1` appended to a bare
  /// origin). Returns why it is not usable, or null when applied. Throws
  /// [StateError] in production builds.
  ApiUrlIssue? setServer(String raw) {
    if (!build.allowsServerOverride) throw StateError('The server cannot be changed in a production build.');
    final ({String? url, ApiUrlIssue? issue}) n = AppEnvironment.normalizeApiUrl(raw, allowHttp: build.allowsHttp);
    if (n.url == null) return n.issue;
    _settings.apiServerOverride = n.url == build.apiBaseUrl ? null : n.url;
    _update(_apply(build, n.url));
    return null;
  }

  /// Back to the address compiled into the build.
  void resetServer() {
    _settings.apiServerOverride = null;
    _update(build);
  }

  void _update(AppEnvironment next) {
    _current = next;
    notifyListeners();
  }

  static AppEnvironment _apply(AppEnvironment build, String? override) {
    if (override == null) return build;
    final String? url = AppEnvironment.normalizeApiUrl(override, allowHttp: build.allowsHttp).url;
    if (url == null || url == build.apiBaseUrl) return build;
    return build.copyWith(apiBaseUrl: url);
  }
}
