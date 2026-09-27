import 'dart:async';
import 'dart:convert';
import 'dart:io' show OSError, SocketException;

import 'package:clock/clock.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/app/app_scope.dart';
import 'package:giftcard_waiter/core/api/api_client.dart';
import 'package:giftcard_waiter/core/api/waiter_api.dart';
import 'package:giftcard_waiter/core/config/environment.dart';
import 'package:giftcard_waiter/core/config/environment_controller.dart';
import 'package:giftcard_waiter/core/diagnostics/diagnostic_log.dart';
import 'package:giftcard_waiter/core/platform/biometrics_service.dart';
import 'package:giftcard_waiter/core/platform/channels.dart';
import 'package:giftcard_waiter/core/platform/connectivity_service.dart';
import 'package:giftcard_waiter/core/platform/feedback_service.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/core/platform/system_service.dart';
import 'package:giftcard_waiter/core/state/business_calendar.dart';
import 'package:giftcard_waiter/core/state/client_identity.dart';
import 'package:giftcard_waiter/core/state/clock.dart';
import 'package:giftcard_waiter/core/state/loop_controller.dart';
import 'package:giftcard_waiter/core/state/session_controller.dart';
import 'package:giftcard_waiter/core/storage/recent_store.dart';
import 'package:giftcard_waiter/core/storage/secure_store.dart';
import 'package:giftcard_waiter/core/storage/settings_store.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Monotonic clock driven by `package:clock`, so `fakeAsync` / `tester.pump`
/// advance it together with timers.
class TestMonotonicClock implements MonotonicClock {
  TestMonotonicClock() : _start = clock.now();

  final DateTime _start;

  @override
  Duration now() => clock.now().difference(_start);

  @override
  Timer timer(Duration after, void Function() callback) => Timer(after, callback);
}

/// One scripted HTTP answer.
class FakeReply {
  FakeReply(this.status, [this.body = const <String, Object?>{}, this.delay = Duration.zero]);

  /// No response at all (transport failure).
  FakeReply.transport() : status = -1, body = const <String, Object?>{}, delay = Duration.zero;

  /// The host name does not resolve (as for an unregistered domain).
  FakeReply.dns() : status = -3, body = const <String, Object?>{}, delay = Duration.zero;

  /// Nothing listens at the address (server not started).
  FakeReply.refused() : status = -4, body = const <String, Object?>{}, delay = Duration.zero;

  /// Hangs until [delay] (for timeouts).
  FakeReply.hang(this.delay) : status = -2, body = const <String, Object?>{};

  final int status;
  final Map<String, Object?> body;
  final Duration delay;
}

/// Scriptable backend: replies are queued per `METHOD path`; every request is
/// recorded with its headers and body.
class FakeBackend implements HttpClientAdapter {
  final Map<String, List<FakeReply>> _replies = <String, List<FakeReply>>{};
  final List<RecordedRequest> requests = <RecordedRequest>[];

  void on(String method, String path, FakeReply reply) =>
      _replies.putIfAbsent('$method $path', () => <FakeReply>[]).add(reply);

  /// Replaces every scripted reply for `METHOD path` with [reply].
  void only(String method, String path, FakeReply reply) => _replies['$method $path'] = <FakeReply>[reply];

  List<RecordedRequest> to(String method, String path) =>
      requests.where((RecordedRequest r) => r.method == method && r.path == path).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final String path = options.uri.path.replaceFirst(RegExp(r'^/api/v1'), '');
    Map<String, Object?>? body;
    if (options.data is Map) body = (options.data as Map<Object?, Object?>).cast<String, Object?>();
    requests.add(RecordedRequest(options.method, path, Map<String, Object?>.from(options.headers), body));

    final List<FakeReply>? queue = _replies['${options.method} $path'];
    if (queue == null || queue.isEmpty) {
      throw StateError('No fake reply for ${options.method} $path');
    }
    final FakeReply reply = queue.length > 1 ? queue.removeAt(0) : queue.first;

    if (reply.status == -2) {
      final Completer<ResponseBody> never = Completer<ResponseBody>();
      unawaited(cancelFuture?.then((_) {
        if (!never.isCompleted) never.completeError(DioException.requestCancelled(requestOptions: options, reason: 'cancel'));
      }));
      return never.future;
    }
    if (reply.delay > Duration.zero) await Future<void>.delayed(reply.delay);
    if (reply.status == -1) {
      throw DioException.connectionError(requestOptions: options, reason: 'reset');
    }
    if (reply.status == -3) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'lookup',
        error: SocketException(
          "Failed host lookup: '${options.uri.host}'",
          osError: const OSError('No address associated with hostname', 7),
        ),
      );
    }
    if (reply.status == -4) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'refused',
        error: const SocketException('Connection refused', osError: OSError('Connection refused', 111)),
      );
    }
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class RecordedRequest {
  RecordedRequest(this.method, this.path, this.headers, this.body);

  final String method;
  final String path;
  final Map<String, Object?> headers;
  final Map<String, Object?>? body;

  String? header(String name) {
    for (final MapEntry<String, Object?> e in headers.entries) {
      if (e.key.toLowerCase() == name.toLowerCase()) return '${e.value}';
    }
    return null;
  }
}

/// NFC service whose events the test injects.
class FakeNfcService implements NfcService {
  final StreamController<NfcEvent> controller = StreamController<NfcEvent>.broadcast();
  NfcAvailability value = NfcAvailability.enabled;
  final List<String> calls = <String>[];

  void emit(NfcEvent event) => controller.add(event);

  @override
  Stream<NfcEvent> get events => controller.stream;

  @override
  Future<NfcAvailability> availability() async => value;

  @override
  Future<void> setReaderMode({required bool enabled}) async => calls.add('readerMode:$enabled');

  @override
  Future<void> startSession(IosSheetTexts texts) async => calls.add('startSession');

  @override
  Future<void> finishSession() async => calls.add('finishSession');

  @override
  Future<void> rejectTag() async => calls.add('rejectTag');

  @override
  Future<void> openSettings() async => calls.add('openSettings');
}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

/// Sample payloads matching the backend resources.
abstract final class Payloads {
  static const String cardId = '9f1c7a0e-3b2d-4c1a-9e8f-0a1b2c3d4e5f';
  static const String cardToken = 'b8c1d2e3-f4a5-4b6c-8d7e-9f0a1b2c3d4e';

  static Map<String, Object?> user({bool partial = true, int? maxSingle}) => <String, Object?>{
        'id': 'u-1',
        'name': 'Anna Berger',
        'email': 'anna@example.at',
        'permissions': <String>['cards.scan', 'cards.redeem'],
        'restaurant': <String, Object?>{
          'id': 'r-1',
          'name': 'Trattoria Bella Vista',
          'currency': 'EUR',
          'timezone': 'Europe/Vienna',
          'locale': 'de_AT',
          'settings': <String, Object?>{
            'allow_partial_redemption': partial,
            'max_single_redemption': maxSingle,
            'brand_color': '#0F172A',
          },
        },
      };

  static Map<String, Object?> token() => <String, Object?>{
        'data': <String, Object?>{'token': 'gcp_test', 'expires_at': '2026-10-27T00:00:00Z', 'user': user()},
      };

  static Map<String, Object?> card({int balance = 5000, String status = 'active', bool partial = true}) => <String, Object?>{
        'id': cardId,
        'restaurant_name': 'Trattoria Bella Vista',
        'card_number': '5285 1058 7098 6488',
        'status': status,
        'currency': 'EUR',
        'balance': balance,
        'expires_at': '2029-09-26T00:00:00Z',
        'is_expired': false,
        'blocked_reason': status == 'blocked' ? 'Reported lost' : null,
        'allow_partial_redemption': partial,
        'actions': <String, Object?>{'redeem': status == 'active' && balance > 0},
      };

  static Map<String, Object?> scan({int balance = 5000, String status = 'active', bool partial = true}) =>
      <String, Object?>{'data': card(balance: balance, status: status, partial: partial)};

  static Map<String, Object?> redeemed({required int amount, required int balanceAfter, bool replayed = false}) =>
      <String, Object?>{
        'data': <String, Object?>{
          'card': card(balance: balanceAfter, status: balanceAfter == 0 ? 'redeemed' : 'active'),
          'transaction': <String, Object?>{
            'id': 'tx-$amount-$balanceAfter',
            'amount': -amount,
            'balance_after': balanceAfter,
            'created_at': '2026-09-26T12:00:00Z',
          },
        },
        'replayed': replayed,
      };

  static Map<String, Object?> config({bool updateRequired = false, String? notice}) => <String, Object?>{
        'data': <String, Object?>{
          'min_version': <String, Object?>{'android': null, 'ios': null},
          'update_required': updateRequired,
          'maintenance_notice': notice,
          'support_email': 'support@example.at',
          'card_domains': <String>['cards.example.at'],
        },
      };

  static Map<String, Object?> error(String code, [Map<String, Object?> context = const <String, Object?>{}]) =>
      <String, Object?>{'message': code, 'code': code, if (context.isNotEmpty) 'context': context};

  static String cardUrl({bool sun = false}) =>
      'https://cards.example.at/c/$cardToken${sun ? '?picc=0123456789ABCDEF0123456789ABCDEF&cmac=0123456789ABCDEF' : ''}';
}

/// A fully wired app with real controllers and fake platform edges.
class TestApp {
  TestApp._({
    required this.services,
    required this.backend,
    required this.nfc,
    required this.secrets,
    required this.localAuth,
    required this.feedbackCalls,
    required this.connectivity,
  });

  final AppServices services;
  final FakeBackend backend;
  final FakeNfcService nfc;
  final MemorySecretStore secrets;
  final MockLocalAuthentication localAuth;
  final List<MethodCall> feedbackCalls;
  final ConnectivityService connectivity;

  SessionController get session => services.session;
  LoopController get loop => services.loop;

  /// Cancels every timer (rollover, countdowns) so no timer outlives the test.
  void dispose() {
    services.loop.dispose();
    services.session.dispose();
  }

  /// Haptic token ids played so far, e.g. `haptic.success` → derived from the
  /// iOS/Android payload is not needed: the test compares [feedbackCalls].
  List<String> get sounds => <String>[
        for (final MethodCall c in feedbackCalls)
          if (c.method == 'sound') (c.arguments as Map<Object?, Object?>)['file']! as String,
      ];

  static Future<TestApp> create({
    bool signedIn = true,
    bool biometrics = false,
    bool introDone = true,
    bool biometricsOffered = true,
    bool isIos = false,
    Map<String, Object?>? user,
    Map<String, Object> prefs = const <String, Object>{},
    AppEnvironment environment = const AppEnvironment(
      apiBaseUrl: 'https://cards.example.at/api/v1',
      cardDomains: <String>['cards.example.at'],
    ),
  }) async {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(<String, Object>{
      'installed': true,
      'intro_done': introDone,
      'biometrics_offered': biometricsOffered,
      'biometrics_enabled': biometrics,
      ...prefs,
    });
    final SettingsStore settings = await SettingsStore.load();

    final List<MethodCall> feedbackCalls = <MethodCall>[];
    final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(WaiterChannels.feedback, (MethodCall call) async {
      feedbackCalls.add(call);
      return null;
    });
    messenger.setMockMethodCallHandler(WaiterChannels.system, (MethodCall call) async {
      switch (call.method) {
        case 'deviceFacts':
          return <String, Object?>{'platform': isIos ? 'ios' : 'android', 'osVersion': '14', 'model': 'Pixel 7', 'isTablet': false};
        case 'biometricEnrollment':
          return 'valid';
      }
      return null;
    });

    final MemorySecretStore secrets = MemorySecretStore();
    if (signedIn) {
      secrets.values['token'] = 'gcp_test';
      secrets.values['profile'] = jsonEncode(user ?? Payloads.user());
      secrets.values['biometric_enrollment'] = 'valid';
    }

    final DiagnosticLog log = DiagnosticLog();
    final AppClientIdentity identity = AppClientIdentity(
      deviceId: '00000000-0000-4000-8000-000000000001',
      userAgent: 'GiftCardWaiter/1.0.0 (Android 14; Pixel 7)',
      language: 'en',
    );
    final FakeBackend backend = FakeBackend()..on('GET', '/app/config', FakeReply(200, Payloads.config()));
    final Dio dio = Dio()..httpClientAdapter = backend;
    final EnvironmentController environments = EnvironmentController(build: environment, settings: settings);
    final ApiClient client = ApiClient(baseUrl: environments.current.apiBaseUrl, identity: identity, dio: dio, log: log);
    final WaiterApi api = WaiterApi(client);

    final FeedbackService feedback = FeedbackService(settings: settings, log: log);
    final MockLocalAuthentication localAuth = MockLocalAuthentication();
    when(localAuth.isDeviceSupported).thenAnswer((_) async => true);
    when(localAuth.getAvailableBiometrics).thenAnswer((_) async => <BiometricType>[BiometricType.strong]);
    final SystemService system = SystemService();
    final BiometricsService biometricsService = BiometricsService(system: system, auth: localAuth);
    final RecentStore recent = RecentStore(secrets);
    final TestMonotonicClock monotonic = TestMonotonicClock();
    final FakeNfcService nfc = FakeNfcService();
    final ConnectivityService connectivity = ConnectivityService.fixed();

    final SessionController session = SessionController(
      api: api,
      secrets: secrets,
      settings: settings,
      recent: recent,
      biometrics: biometricsService,
      feedback: feedback,
      identity: identity,
      clock: monotonic,
      calendar: BusinessCalendar(),
      appVersion: '1.0.0',
      platform: isIos ? 'ios' : 'android',
      deviceName: 'Pixel 7',
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
      clock: monotonic,
      cardDomains: environments.current.cardDomains,
      allowHttpLinks: environment.allowsHttp,
      isIos: isIos,
      log: log,
    );
    environments.addListener(() {
      client.baseUrl = environments.current.apiBaseUrl;
      loop.cardDomains = environments.current.cardDomains;
    });

    return TestApp._(
      services: AppServices(
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
        appVersion: '1.0.0',
        buildNumber: '1',
        isTablet: false,
      ),
      backend: backend,
      nfc: nfc,
      secrets: secrets,
      localAuth: localAuth,
      feedbackCalls: feedbackCalls,
      connectivity: connectivity,
    );
  }
}
