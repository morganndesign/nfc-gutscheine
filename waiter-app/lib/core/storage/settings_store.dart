import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// Theme override in the Menu (09 §2.4): System / Light / Dark.
enum ThemePreference { system, light, dark }

/// Ordinary preferences (09 §7.5: not secrets). Changes notify listeners so the
/// app applies them immediately (theme without restart, 09 §2.4).
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs);

  static Future<SettingsStore> load() async => SettingsStore._(await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      ));

  final SharedPreferencesWithCache _prefs;

  static const String _theme = 'theme';
  static const String _sound = 'sound';
  static const String _haptics = 'haptics';
  static const String _keepAwake = 'keep_screen_on';
  static const String _biometrics = 'biometrics_enabled';
  static const String _biometricsOffered = 'biometrics_offered';
  static const String _introDone = 'intro_done';
  static const String _installed = 'installed';
  static const String _lastEmail = 'last_email';
  static const String _apiServer = 'api_server_override';
  static const String _sessionServer = 'session_server';

  ThemePreference get theme =>
      ThemePreference.values.asNameMap()[_prefs.getString(_theme)] ?? ThemePreference.system;
  set theme(ThemePreference value) => _set(() => _prefs.setString(_theme, value.name));

  /// Menu "Töne" (default on, 09 §7.8).
  bool get sound => _prefs.getBool(_sound) ?? true;
  set sound(bool value) => _set(() => _prefs.setBool(_sound, value));

  /// Menu "Vibration" (default on).
  bool get haptics => _prefs.getBool(_haptics) ?? true;
  set haptics(bool value) => _set(() => _prefs.setBool(_haptics, value));

  /// Menu "Bildschirm anlassen" (default on, 09 §7.7).
  bool get keepScreenOn => _prefs.getBool(_keepAwake) ?? true;
  set keepScreenOn(bool value) => _set(() => _prefs.setBool(_keepAwake, value));

  bool get biometricsEnabled => _prefs.getBool(_biometrics) ?? false;
  set biometricsEnabled(bool value) => _set(() => _prefs.setBool(_biometrics, value));

  /// S03 is offered once per install (02 §4.3).
  bool get biometricsOffered => _prefs.getBool(_biometricsOffered) ?? false;
  set biometricsOffered(bool value) => _set(() => _prefs.setBool(_biometricsOffered, value));

  /// S17 is shown once per install.
  bool get introDone => _prefs.getBool(_introDone) ?? false;
  set introDone(bool value) => _set(() => _prefs.setBool(_introDone, value));

  /// Absent on the first launch after (re)install — iOS keeps Keychain items
  /// across reinstalls, so the app wipes them then (09 §7.5).
  bool get installedMarker => _prefs.getBool(_installed) ?? false;
  set installedMarker(bool value) => _set(() => _prefs.setBool(_installed, value));

  /// E-mail prefilled on S02 and the S15 session sheet (A01).
  String? get lastEmail => _prefs.getString(_lastEmail);
  set lastEmail(String? value) =>
      _set(() => value == null ? _prefs.remove(_lastEmail) : _prefs.setString(_lastEmail, value));

  /// Server address chosen in a development or staging build (never read in
  /// production builds). Null = the address compiled into the build.
  String? get apiServerOverride => _prefs.getString(_apiServer);
  set apiServerOverride(String? value) =>
      _set(() => value == null ? _prefs.remove(_apiServer) : _prefs.setString(_apiServer, value));

  /// API address the stored sign-in belongs to (a token of one server is never
  /// sent to another — e.g. a development build replaced by a store build on iOS,
  /// where all environments share one bundle id).
  String? get sessionServer => _prefs.getString(_sessionServer);
  set sessionServer(String? value) =>
      _set(() => value == null ? _prefs.remove(_sessionServer) : _prefs.setString(_sessionServer, value));

  /// Sign-out keeps display preferences but forgets account-specific choices.
  Future<void> resetAccount() async {
    await _prefs.remove(_biometrics);
    notifyListeners();
  }

  void _set(Future<void> Function() write) {
    unawaited(write());
    notifyListeners();
  }
}
