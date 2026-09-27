import 'package:flutter/widgets.dart';

import '../core/config/environment.dart';
import '../core/config/environment_controller.dart';
import '../core/diagnostics/diagnostic_log.dart';
import '../core/platform/biometrics_service.dart';
import '../core/platform/connectivity_service.dart';
import '../core/platform/feedback_service.dart';
import '../core/platform/nfc_service.dart';
import '../core/platform/system_service.dart';
import '../core/state/client_identity.dart';
import '../core/state/loop_controller.dart';
import '../core/state/session_controller.dart';
import '../core/storage/recent_store.dart';
import '../core/storage/settings_store.dart';

/// Everything the widgets need, created once in `bootstrap()`.
@immutable
class AppServices {
  const AppServices({
    required this.environmentController,
    required this.session,
    required this.loop,
    required this.settings,
    required this.recent,
    required this.feedback,
    required this.nfc,
    required this.system,
    required this.connectivity,
    required this.identity,
    required this.log,
    required this.appVersion,
    required this.buildNumber,
    required this.isTablet,
  });

  /// Build configuration + server override (development / staging).
  final EnvironmentController environmentController;

  /// The environment in use.
  AppEnvironment get environment => environmentController.current;
  final SessionController session;
  final LoopController loop;
  final SettingsStore settings;
  final RecentStore recent;
  final FeedbackService feedback;
  final NfcService nfc;
  final SystemService system;
  final ConnectivityService connectivity;

  /// Request identity; its language follows the UI language.
  final AppClientIdentity identity;
  final DiagnosticLog log;
  final String appVersion;
  final String buildNumber;
  final bool isTablet;

  BiometricKind get biometricKind => session.biometricKind;
}

/// Provides [AppServices] to the widget tree. Controllers are listened to with
/// `ListenableBuilder` where a widget needs to rebuild.
class AppScope extends InheritedWidget {
  const AppScope({required this.services, required super.child, super.key});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final AppScope? scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget.');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => !identical(services, oldWidget.services);
}

extension AppScopeContext on BuildContext {
  AppServices get services => AppScope.of(this);
}
