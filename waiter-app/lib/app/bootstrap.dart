import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../core/api/api_client.dart';
import '../core/api/waiter_api.dart';
import '../core/config/environment.dart';
import '../core/config/environment_controller.dart';
import '../core/diagnostics/diagnostic_log.dart';
import '../core/l10n/l10n.dart';
import '../core/platform/biometrics_service.dart';
import '../core/platform/connectivity_service.dart';
import '../core/platform/feedback_service.dart';
import '../core/platform/nfc_service.dart';
import '../core/platform/system_service.dart';
import '../core/state/business_calendar.dart';
import '../core/state/client_identity.dart';
import '../core/state/clock.dart';
import '../core/state/loop_controller.dart';
import '../core/state/session_controller.dart';
import '../core/state/session_isolation.dart';
import '../core/storage/recent_store.dart';
import '../core/storage/secure_store.dart';
import '../core/storage/settings_store.dart';
import 'app_scope.dart';

const String _deviceIdKey = 'device_id';

/// Creates every service of the app (09 §6.2 wave 0) before the first frame.
/// The access decision itself (S01 → S02/S04/S05) runs in
/// [SessionController.start] while the splash is visible.
///
/// Throws [ConfigurationProblem] for an unusable build configuration and a
/// `PlatformException` when secure storage cannot be opened; `main` then shows
/// the startup problem screen.
Future<AppServices> bootstrap() async {
  final AppEnvironment build = AppEnvironment.fromDefines();
  final DiagnosticLog log = DiagnosticLog();
  final SettingsStore settings = await SettingsStore.load();
  final EnvironmentController environments = EnvironmentController(build: build, settings: settings);
  final AppEnvironment environment = environments.current;
  log.record('environment', '${build.flavor.name} ${environment.apiBaseUrl}');
  final SecretStore secrets = PlatformSecretStore();

  // iOS keeps Keychain items across reinstalls: a fresh install starts signed
  // out with a new device id (09 §7.5).
  if (!settings.installedMarker) {
    await secrets.deleteAll();
    settings.installedMarker = true;
  }
  // A sign-in belongs to the server it was made on (development / staging / production).
  if (await forgetSessionOfOtherServer(settings: settings, secrets: secrets, apiBaseUrl: environment.apiBaseUrl)) {
    log.record('session.otherServer', 'signed out: stored sign-in belonged to another server');
  }
  String? deviceId = await secrets.read(_deviceIdKey);
  if (deviceId == null) {
    deviceId = const Uuid().v4();
    await secrets.write(_deviceIdKey, deviceId);
  }

  final SystemService system = SystemService();
  final DeviceFacts facts = await system.deviceFacts();
  final PackageInfo package = await PackageInfo.fromPlatform();
  final bool isIos = facts.platform == 'ios';

  // Phones are portrait-locked (R13, 08 §4); tablets rotate freely.
  if (!facts.isTablet) {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[DeviceOrientation.portraitUp]);
  }
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final AppClientIdentity identity = AppClientIdentity(
    deviceId: deviceId,
    userAgent: 'GiftCardWaiter/${package.version} (${isIos ? 'iOS' : 'Android'} ${facts.osVersion}; ${facts.model})',
    language: uiLanguageOf(PlatformDispatcher.instance.locale).apiCode,
  );
  final ApiClient client = ApiClient(baseUrl: environment.apiBaseUrl, identity: identity, log: log, dio: Dio());
  final WaiterApi api = WaiterApi(client);

  final FeedbackService feedback = FeedbackService(settings: settings, log: log);
  unawaited(feedback.preload());
  final NfcService nfc = PlatformNfcService();
  final ConnectivityService connectivity = ConnectivityService();
  await connectivity.start();
  final RecentStore recent = RecentStore(secrets);
  final MonotonicClock clock = SystemMonotonicClock();

  final SessionController session = SessionController(
    api: api,
    secrets: secrets,
    settings: settings,
    recent: recent,
    biometrics: BiometricsService(system: system),
    feedback: feedback,
    identity: identity,
    clock: clock,
    calendar: BusinessCalendar(),
    appVersion: package.version,
    platform: facts.platform,
    deviceName: facts.model,
    log: log,
  );
  final LoopController loop = LoopController(
    session: session,
    api: api,
    nfc: nfc,
    feedback: feedback,
    recent: recent,
    connectivity: connectivity,
    settings: settings,
    clock: clock,
    cardDomains: environment.cardDomains,
    allowHttpLinks: environment.allowsHttp,
    isIos: isIos,
    log: log,
  );
  // A server chosen in the app (development / staging) takes effect at once.
  environments.addListener(() {
    client.baseUrl = environments.current.apiBaseUrl;
    loop.cardDomains = environments.current.cardDomains;
    settings.sessionServer = environments.current.apiBaseUrl;
    log.record('environment', environments.current.apiBaseUrl);
  });
  await loop.refreshNfcAvailability();

  return AppServices(
    environmentController: environments,
    session: session,
    loop: loop,
    settings: settings,
    recent: recent,
    feedback: feedback,
    nfc: nfc,
    system: system,
    connectivity: connectivity,
    identity: identity,
    log: log,
    appVersion: package.version,
    buildNumber: package.buildNumber,
    isTablet: facts.isTablet,
  );
}
