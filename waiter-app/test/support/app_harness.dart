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
import 'package:giftcard_waiter/core/platform/system_service.dart';
import 'package:giftcard_waiter/core/platform/voucher_printer.dart';
import 'package:giftcard_waiter/core/state/business_calendar.dart';
import 'package:giftcard_waiter/core/state/client_identity.dart';
import 'package:giftcard_waiter/core/state/clock.dart';
import 'package:giftcard_waiter/core/state/loop_controller.dart';
import 'package:giftcard_waiter/core/state/session_controller.dart';
import 'package:giftcard_waiter/core/storage/pending_redemptions.dart';
import 'package:giftcard_waiter/core/storage/recent_store.dart';
import 'package:giftcard_waiter/core/storage/secure_store.dart';
import 'package:giftcard_waiter/core/storage/settings_store.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fake_nfc.dart';

export 'fake_nfc.dart';

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

  /// Answers every `METHOD <prefix>…` without its own script with [reply]
  /// (paths that contain a key generated during the test).
  void onPrefix(String method, String prefix, FakeReply reply) => _prefixes['$method $prefix'] = reply;

  final Map<String, FakeReply> _prefixes = <String, FakeReply>{};

  List<RecordedRequest> to(String method, String path) =>
      requests.where((RecordedRequest r) => r.method == method && r.path == path).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    final String path = options.uri.path.replaceFirst(RegExp(r'^/api/v1'), '');
    Map<String, Object?>? body;
    if (options.data is Map) body = (options.data as Map<Object?, Object?>).cast<String, Object?>();
    requests.add(RecordedRequest(options.method, path, Map<String, Object?>.from(options.headers), body));

    final List<FakeReply>? queue = _replies['${options.method} $path'];
    final FakeReply reply;
    if (queue != null && queue.isNotEmpty) {
      reply = queue.length > 1 ? queue.removeAt(0) : queue.first;
    } else {
      final String? prefix = _prefixes.keys
          .where((String k) => '${options.method} $path'.startsWith(k))
          .fold<String?>(null, (String? best, String k) => best == null || k.length > best.length ? k : best);
      if (prefix == null) throw StateError('No fake reply for ${options.method} $path');
      reply = _prefixes[prefix]!;
    }

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

/// Records print jobs instead of opening the system dialog.
class FakeVoucherPrinter implements VoucherPrinter {
  final List<PrintableVoucher> jobs = <PrintableVoucher>[];

  /// What the next print returns (false = dialog closed without printing).
  bool result = true;

  /// Throws instead (printing unavailable).
  bool fail = false;

  @override
  Future<bool> print(PrintableVoucher voucher) async {
    jobs.add(voucher);
    if (fail) throw StateError('no printer');
    return result;
  }
}

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

/// Sample payloads matching the backend resources.
abstract final class Payloads {
  static const String voucherId = '9f1c7a0e-3b2d-4c1a-9e8f-0a1b2c3d4e5f';
  static const String presentmentId = '7d6c5b4a-3928-4716-a5b4-c3d2e1f0a9b8';

  /// A printable voucher's QR text (`GCPV1.` + 43 base64url characters).
  static const String qr = 'GCPV1.AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_AbCdE';

  static Map<String, Object?> user({bool partial = true, int? maxSingle, bool emails = true}) => <String, Object?>{
    'id': 'u-1',
    'name': 'Anna Berger',
    'email': 'anna@example.at',
    'permissions': <String>['vouchers.redeem'],
    'restaurant': <String, Object?>{
      'id': 'r-1',
      'name': 'Trattoria Bella Vista',
      'currency': 'EUR',
      'timezone': 'Europe/Vienna',
      'locale': 'de_AT',
      'settings': <String, Object?>{
        'allow_partial_redemption': partial,
        'max_debit_per_transaction': maxSingle,
        'brand_color': '#0F172A',
        'min_voucher_value': 500,
        'max_voucher_balance': 50000,
        'send_customer_emails': emails,
      },
    },
  };

  /// A manager or owner: selling (owners also complimentary).
  static Map<String, Object?> manager({String role = 'manager', bool selling = true}) => <String, Object?>{
    ...user(),
    'id': 'u-2',
    'name': 'Mia Manager',
    'email': 'mia@example.at',
    'role': <String, Object?>{'slug': role, 'name': role},
    'permissions': <String>[
      'vouchers.redeem',
      if (selling) 'vouchers.sell',
      if (selling && role == 'owner') 'vouchers.sell_complimentary',
    ],
  };

  static const String soldId = '0f1e2d3c-4b5a-4968-8776-655443322110';

  static Map<String, Object?> sold({int value = 5000, bool replayed = false, String? payload, bool withQr = true}) =>
      <String, Object?>{
        'data': <String, Object?>{
          'id': soldId,
          'kind': 'digital',
          'voucher_number': '1268834313520042',
          'status': 'active',
          'currency': 'EUR',
          'balance': value,
          'expires_at': null,
        },
        'printable': withQr ? <String, Object?>{'payload': payload ?? qr, 'qr_svg': '<svg/>'} : null,
        'replayed': replayed,
      };

  static Map<String, Object?> token() => <String, Object?>{
    'data': <String, Object?>{'token': 'gcp_test', 'expires_at': '2026-10-27T00:00:00Z', 'user': user()},
  };

  static Map<String, Object?> voucher({int balance = 5000, String status = 'active', bool partial = true, int? max}) =>
      <String, Object?>{
        'id': voucherId,
        'kind': 'digital',
        'restaurant_name': 'Trattoria Bella Vista',
        'voucher_number': '5285 1058 7098 6488',
        'status': status,
        'currency': 'EUR',
        'balance': balance,
        'expires_at': '2029-09-26T00:00:00Z',
        'is_expired': false,
        'blocked_reason': status == 'blocked' ? 'Reported lost' : null,
        'allow_partial_redemption': partial,
        'max_debit_per_transaction': max,
        'actions': <String, Object?>{'redeem': status == 'active' && balance > 0},
      };

  /// `POST /presentments` → 201.
  static Map<String, Object?> presentment({
    int balance = 5000,
    String status = 'active',
    bool partial = true,
    int? max,
    int expiresIn = 60,
    String id = presentmentId,
  }) => <String, Object?>{
    'data': <String, Object?>{
      'id': id,
      'purpose': 'spend',
      'method': 'printable_qr',
      'level': 1,
      'expires_at': '2026-09-26T12:01:00Z',
      'expires_in': expiresIn,
      'voucher': voucher(balance: balance, status: status, partial: partial, max: max),
    },
  };

  static Map<String, Object?> cardChallenge({String authentication = cardAuthentication}) => <String, Object?>{
    'data': <String, Object?>{
      'authentication': authentication,
      'command': '90AF000020${'35C3E05A752E0144BAC0DE51C1F22C56B34408A23D8AEA266CAB947EA8E0118D'}00',
      'expires_in': 30,
    },
  };

  static const String cardAuthentication = '01JQ7Z8X9Y0A1B2C3D4E5F6G7H';

  static Map<String, Object?> cardPresentment({int balance = 5000, String status = 'active'}) {
    final Map<String, Object?> p = presentment(balance: balance, status: status);
    final Map<String, Object?> data = Map<String, Object?>.of(p['data']! as Map<String, Object?>)
      ..['method'] = 'live_auth'
      ..['level'] = 'A3'
      ..['card'] = <String, Object?>{'card_number': 'B-2026-0001-0001', 'state': 'active'};
    return <String, Object?>{'data': data};
  }

  static Map<String, Object?> transaction({required int amount, required int balanceAfter}) => <String, Object?>{
    'id': 'tx-$amount-$balanceAfter',
    'type': 'redemption',
    'amount': -amount,
    'balance_before': balanceAfter + amount,
    'balance_after': balanceAfter,
    'currency': 'EUR',
    'created_at': '2026-09-26T12:00:00Z',
  };

  static Map<String, Object?> redeemed({required int amount, required int balanceAfter, bool replayed = false}) =>
      <String, Object?>{
        'data': <String, Object?>{
          'voucher': voucher(balance: balanceAfter),
          'transaction': transaction(amount: amount, balanceAfter: balanceAfter),
        },
        'replayed': replayed,
      };

  /// `GET /vouchers/{id}/redemptions/{key}`.
  static Map<String, Object?> outcome({int? amount, int? balanceAfter}) => amount == null
      ? <String, Object?>{
          'data': <String, Object?>{'status': 'not_booked'},
        }
      : <String, Object?>{
          'data': <String, Object?>{
            'status': 'booked',
            'voucher': voucher(balance: balanceAfter!),
            'transaction': transaction(amount: amount, balanceAfter: balanceAfter),
          },
        };

  static Map<String, Object?> config({bool updateRequired = false, String? notice}) => <String, Object?>{
    'data': <String, Object?>{
      'min_version': <String, Object?>{'android': null, 'ios': null},
      'update_required': updateRequired,
      'maintenance_notice': notice,
      'support_email': 'support@example.at',
    },
  };

  static Map<String, Object?> error(String code, [Map<String, Object?> context = const <String, Object?>{}]) =>
      <String, Object?>{'message': code, 'code': code, if (context.isNotEmpty) 'context': context};
}

/// A fully wired app with real controllers and fake platform edges.
class TestApp {
  TestApp._({
    required this.services,
    required this.backend,
    required this.printer,
    required this.secrets,
    required this.localAuth,
    required this.feedbackCalls,
    required this.connectivity,
    required this.nfc,
  });

  final AppServices services;
  final FakeBackend backend;
  final FakeVoucherPrinter printer;
  final MemorySecretStore secrets;
  final MockLocalAuthentication localAuth;
  final List<MethodCall> feedbackCalls;
  final ConnectivityService connectivity;

  /// The phone's card reader with a scripted card.
  final FakeNfcRelay nfc;

  SessionController get session => services.session;
  LoopController get loop => services.loop;
  PendingRedemptionStore get pending => services.pending;

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
    DateTime Function()? wallClock,
    AppEnvironment environment = const AppEnvironment(apiBaseUrl: 'https://cards.example.at/api/v1'),
    FakeNfcRelay? nfc,
  }) async {
    final FakeNfcRelay cardReader = nfc ?? FakeNfcRelay();
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
    final PendingRedemptionStore pending = PendingRedemptionStore(
      secrets,
      now: wallClock ?? () => clock.now(),
      monotonic: monotonic,
    );
    final FakeVoucherPrinter printer = FakeVoucherPrinter();
    final ConnectivityService connectivity = ConnectivityService.fixed();

    final SessionController session = SessionController(
      api: api,
      secrets: secrets,
      settings: settings,
      recent: recent,
      pending: pending,
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
      feedback: feedback,
      recent: recent,
      pending: pending,
      connectivity: connectivity,
      clock: monotonic,
      nfc: cardReader,
      log: log,
    );
    environments.addListener(() => client.baseUrl = environments.current.apiBaseUrl);

    return TestApp._(
      services: AppServices(
        environmentController: environments,
        session: session,
        loop: loop,
        settings: settings,
        recent: recent,
        pending: pending,
        feedback: feedback,
        system: system,
        connectivity: connectivity,
        identity: identity,
        log: log,
        appVersion: '1.0.0',
        buildNumber: '1',
        isTablet: false,
        api: api,
        printer: printer,
      ),
      backend: backend,
      printer: printer,
      secrets: secrets,
      localAuth: localAuth,
      feedbackCalls: feedbackCalls,
      connectivity: connectivity,
      nfc: cardReader,
    );
  }
}
