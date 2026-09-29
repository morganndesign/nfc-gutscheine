import 'package:flutter/foundation.dart';

/// Which backend a build talks to. Chosen at build time with the `APP_ENV`
/// define, normally from `config/<environment>.json`
/// (`flutter run --dart-define-from-file=config/development.json`).
enum AppFlavor {
  /// Local backend on the developer's computer. `http` allowed.
  development,

  /// Test server with production-like setup. `https` only.
  staging,

  /// Live system. `https` only, the server cannot be changed in the app.
  production;

  static AppFlavor? parse(String value) => switch (value.trim().toLowerCase()) {
        'development' || 'dev' => AppFlavor.development,
        'staging' => AppFlavor.staging,
        'production' || 'prod' => AppFlavor.production,
        _ => null,
      };
}

/// Why a server address is not usable (shown on the server sheet and, for the
/// build configuration, on the startup problem screen).
enum ApiUrlIssue {
  /// Nothing configured.
  missing,

  /// Not an absolute `http(s)://host…` URL.
  malformed,

  /// `http` in a staging or production build.
  httpsRequired,

  /// The path is not the API root (`…/api/v1`).
  wrongPath,
}

/// The build configuration is unusable: the app shows the "App not set up
/// correctly" screen instead of starting (never an endless splash).
class ConfigurationProblem implements Exception {
  const ConfigurationProblem(this.detail);

  /// Technical reason, shown in small print (e.g. `API_BASE_URL is empty`).
  final String detail;

  @override
  String toString() => 'ConfigurationProblem: $detail';
}

/// Build configuration (09 §9.1) plus the optional server
/// override of development and staging builds.
///
/// Values come from `--dart-define` / `--dart-define-from-file`:
///
/// | Define | Meaning |
/// |---|---|
/// | `APP_ENV` | `development`, `staging` or `production` (missing → production rules) |
/// | `API_BASE_URL` | API root, e.g. `https://app.giftcardpro.at/api/v1` |
/// | `APP_STORE_URL`, `PLAY_STORE_URL` | store listings for "Update required" |
@immutable
class AppEnvironment {
  const AppEnvironment({
    required this.apiBaseUrl,
    this.flavor = AppFlavor.production,
    String? buildApiBaseUrl,
    this.appStoreUrl,
    this.playStoreUrl,
  }) : _buildApiBaseUrl = buildApiBaseUrl;

  /// Reads the compile-time definitions. Throws [ConfigurationProblem] for an
  /// unusable build. A server override is applied by `EnvironmentController`.
  factory AppEnvironment.fromDefines() => AppEnvironment.resolve(
        const <String, String>{
          'APP_ENV': String.fromEnvironment('APP_ENV'),
          'API_BASE_URL': String.fromEnvironment('API_BASE_URL'),
          'APP_STORE_URL': String.fromEnvironment('APP_STORE_URL'),
          'PLAY_STORE_URL': String.fromEnvironment('PLAY_STORE_URL'),
        },
      );

  /// Pure form of [AppEnvironment.fromDefines] (testable).
  factory AppEnvironment.resolve(Map<String, String> defines) {
    final String envName = defines['APP_ENV'] ?? '';
    final AppFlavor? parsed = envName.trim().isEmpty ? AppFlavor.production : AppFlavor.parse(envName);
    if (parsed == null) {
      throw ConfigurationProblem('APP_ENV "$envName" is not development, staging or production');
    }
    final AppFlavor flavor = parsed;

    final String rawApi = defines['API_BASE_URL'] ?? '';
    final ({String? url, ApiUrlIssue? issue}) api = normalizeApiUrl(rawApi, allowHttp: flavor == AppFlavor.development);
    if (api.url == null) {
      throw ConfigurationProblem(switch (api.issue!) {
        ApiUrlIssue.missing => 'API_BASE_URL is empty (build with --dart-define-from-file=config/<environment>.json)',
        ApiUrlIssue.malformed => 'API_BASE_URL "$rawApi" is not a valid URL',
        ApiUrlIssue.httpsRequired => 'API_BASE_URL must use https in ${flavor.name} builds',
        ApiUrlIssue.wrongPath => 'API_BASE_URL "$rawApi" must end with /api/v1',
      });
    }
    final String buildUrl = api.url!;

    final String appStore = (defines['APP_STORE_URL'] ?? '').trim();
    final String playStore = (defines['PLAY_STORE_URL'] ?? '').trim();
    return AppEnvironment(
      apiBaseUrl: buildUrl,
      flavor: flavor,
      buildApiBaseUrl: buildUrl,
      appStoreUrl: appStore.isEmpty ? null : appStore,
      playStoreUrl: playStore.isEmpty ? null : playStore,
    );
  }

  /// Validates and normalises a server address: trims, drops a trailing
  /// slash and appends `/api/v1` when only the origin was given
  /// (`http://192.168.1.20:8000` → `http://192.168.1.20:8000/api/v1`).
  static ({String? url, ApiUrlIssue? issue}) normalizeApiUrl(String raw, {required bool allowHttp}) {
    final String value = raw.trim();
    if (value.isEmpty) return (url: null, issue: ApiUrlIssue.missing);
    final Uri? uri = Uri.tryParse(value);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty || uri.hasQuery || uri.hasFragment) {
      return (url: null, issue: ApiUrlIssue.malformed);
    }
    if (uri.scheme == 'http' && !allowHttp) return (url: null, issue: ApiUrlIssue.httpsRequired);
    String path = uri.path;
    while (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.isEmpty) {
      path = '/api/v1';
    } else if (!path.endsWith('/api/v1')) {
      return (url: null, issue: ApiUrlIssue.wrongPath);
    }
    return (url: uri.replace(path: path).toString(), issue: null);
  }

  /// Development, staging or production.
  final AppFlavor flavor;

  /// Base URL the app uses, including `/api/v1`, without a trailing slash.
  final String apiBaseUrl;

  final String? _buildApiBaseUrl;

  /// The address compiled into this build (before any override).
  String get buildApiBaseUrl => _buildApiBaseUrl ?? apiBaseUrl;

  /// Whether a server override is in use.
  bool get usesOverride => apiBaseUrl != buildApiBaseUrl;

  /// Store listing opened by S15 "Update now" on iOS.
  final String? appStoreUrl;

  /// Store listing on Android; defaults to the Play listing of the package.
  final String? playStoreUrl;

  bool get isProduction => flavor == AppFlavor.production;

  /// An `http` API is accepted only in development builds.
  bool get allowsHttp => flavor == AppFlavor.development;

  /// Development and staging builds can point at another server in the app.
  bool get allowsServerOverride => flavor != AppFlavor.production;

  /// `host[:port]` of [apiBaseUrl], for problem screens.
  String get apiHost => Uri.parse(apiBaseUrl).authority;

  AppEnvironment copyWith({String? apiBaseUrl}) => AppEnvironment(
        apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
        flavor: flavor,
        buildApiBaseUrl: buildApiBaseUrl,
        appStoreUrl: appStoreUrl,
        playStoreUrl: playStoreUrl,
      );
}
