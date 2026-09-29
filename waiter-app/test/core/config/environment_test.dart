import 'dart:io' show HandshakeException, OSError, SocketException;

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/api/api_client.dart';
import 'package:giftcard_waiter/core/api/api_failure.dart';
import 'package:giftcard_waiter/core/config/environment.dart';
import 'package:giftcard_waiter/core/config/environment_controller.dart';
import 'package:giftcard_waiter/core/state/session_isolation.dart';
import 'package:giftcard_waiter/core/state/startup_problem.dart';
import 'package:giftcard_waiter/core/storage/secure_store.dart';
import 'package:giftcard_waiter/core/storage/settings_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Map<String, String> _defines(String env, String api) => <String, String>{'APP_ENV': env, 'API_BASE_URL': api};

Future<SettingsStore> _settings([Map<String, Object> data = const <String, Object>{}]) async {
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.withData(data);
  return SettingsStore.load();
}

void main() {
  group('AppEnvironment.resolve', () {
    test('development accepts http and appends /api/v1 to a bare origin', () {
      final AppEnvironment e = AppEnvironment.resolve(_defines('development', 'http://10.0.2.2:8000'));
      expect(e.flavor, AppFlavor.development);
      expect(e.apiBaseUrl, 'http://10.0.2.2:8000/api/v1');
      expect(e.apiHost, '10.0.2.2:8000');
      expect(e.allowsHttp, isTrue);
      expect(e.allowsServerOverride, isTrue);
    });

    test('staging and production require https', () {
      for (final String env in <String>['staging', 'production']) {
        expect(
          () => AppEnvironment.resolve(_defines(env, 'http://example.at/api/v1')),
          throwsA(isA<ConfigurationProblem>().having((ConfigurationProblem p) => p.detail, 'detail', contains('https'))),
          reason: env,
        );
      }
    });

    test('a missing APP_ENV applies the production rules', () {
      final AppEnvironment e = AppEnvironment.resolve(_defines('', 'https://app.giftcardpro.at/api/v1'));
      expect(e.flavor, AppFlavor.production);
      expect(e.isProduction, isTrue);
      expect(e.allowsServerOverride, isFalse);
    });

    test('unusable configurations are reported, not ignored', () {
      expect(() => AppEnvironment.resolve(_defines('production', '')), throwsA(isA<ConfigurationProblem>()));
      expect(() => AppEnvironment.resolve(_defines('qa', 'https://x.at/api/v1')), throwsA(isA<ConfigurationProblem>()));
      expect(() => AppEnvironment.resolve(_defines('production', 'https://x.at/v2')), throwsA(isA<ConfigurationProblem>()));
      expect(() => AppEnvironment.resolve(_defines('production', 'x.at/api/v1')), throwsA(isA<ConfigurationProblem>()));
    });

    test('normalizeApiUrl', () {
      expect(AppEnvironment.normalizeApiUrl(' https://a.at/api/v1/ ', allowHttp: false).url, 'https://a.at/api/v1');
      expect(AppEnvironment.normalizeApiUrl('https://a.at/', allowHttp: false).url, 'https://a.at/api/v1');
      expect(AppEnvironment.normalizeApiUrl('http://a.at', allowHttp: false).issue, ApiUrlIssue.httpsRequired);
      expect(AppEnvironment.normalizeApiUrl('https://a.at/api', allowHttp: true).issue, ApiUrlIssue.wrongPath);
      expect(AppEnvironment.normalizeApiUrl('ftp://a.at', allowHttp: true).issue, ApiUrlIssue.malformed);
      expect(AppEnvironment.normalizeApiUrl('', allowHttp: true).issue, ApiUrlIssue.missing);
    });
  });

  group('EnvironmentController', () {
    test('development: a server set in the app is stored, used and can be reset', () async {
      final SettingsStore settings = await _settings();
      final AppEnvironment build = AppEnvironment.resolve(_defines('development', 'http://10.0.2.2:8000/api/v1'));
      final EnvironmentController c = EnvironmentController(build: build, settings: settings);
      int changes = 0;
      c.addListener(() => changes++);

      expect(c.setServer('http://192.168.1.20:8000'), isNull);
      expect(c.current.apiBaseUrl, 'http://192.168.1.20:8000/api/v1');
      expect(settings.apiServerOverride, 'http://192.168.1.20:8000/api/v1');
      expect(changes, 1);

      // A new start picks the stored server up.
      expect(EnvironmentController(build: build, settings: settings).current.apiBaseUrl, 'http://192.168.1.20:8000/api/v1');

      c.resetServer();
      expect(c.current.apiBaseUrl, build.apiBaseUrl);
      expect(settings.apiServerOverride, isNull);
    });

    test('invalid addresses are refused with the reason', () async {
      final EnvironmentController staging = EnvironmentController(
        build: AppEnvironment.resolve(_defines('staging', 'https://staging.example.at/api/v1')),
        settings: await _settings(),
      );
      expect(staging.setServer('http://192.168.1.20:8000'), ApiUrlIssue.httpsRequired);
      expect(staging.setServer('nonsense'), ApiUrlIssue.malformed);
      expect(staging.current.apiBaseUrl, 'https://staging.example.at/api/v1');
    });

    test('production ignores a stored override and cannot change the server', () async {
      final SettingsStore settings = await _settings(<String, Object>{'api_server_override': 'https://evil.example/api/v1'});
      final EnvironmentController c = EnvironmentController(
        build: AppEnvironment.resolve(_defines('production', 'https://app.giftcardpro.at/api/v1')),
        settings: settings,
      );
      expect(c.current.apiBaseUrl, 'https://app.giftcardpro.at/api/v1');
      expect(() => c.setServer('https://other.example/api/v1'), throwsStateError);
    });
  });

  group('failure classification', () {
    final RequestOptions options = RequestOptions(path: '/app/config');

    DioException socket(String message, int code) => DioException.connectionError(
          requestOptions: options,
          reason: message,
          error: SocketException(message, osError: OSError(message, code)),
        );

    test('network stack errors map to a transport issue', () {
      expect(
        ApiClient.classifyTransport(socket("Failed host lookup: 'app.giftcardpro.at'", 7), timedOut: false).$1,
        TransportIssue.hostLookup,
      );
      expect(ApiClient.classifyTransport(socket('Connection refused', 111), timedOut: false).$1, TransportIssue.refused);
      expect(ApiClient.classifyTransport(socket('Connection refused', 61), timedOut: false).$1, TransportIssue.refused);
      expect(ApiClient.classifyTransport(socket('Network is unreachable', 101), timedOut: false).$1, TransportIssue.unreachable);
      expect(
        ApiClient.classifyTransport(
          DioException.connectionError(requestOptions: options, reason: 'tls', error: const HandshakeException('bad cert')),
          timedOut: false,
        ).$1,
        TransportIssue.tls,
      );
      expect(ApiClient.classifyTransport(socket('reset', 104), timedOut: true).$1, TransportIssue.timeout);
    });

    test('startup problems from API failures', () {
      StartupProblemKind kind(ApiFailure f) => StartupProblem.fromApiFailure(f).kind;
      expect(kind(const ApiTransportFailure(requestId: 'r', timedOut: false, issue: TransportIssue.hostLookup)),
          StartupProblemKind.hostNotFound);
      expect(kind(const ApiTransportFailure(requestId: 'r', timedOut: true)), StartupProblemKind.timeout);
      expect(kind(const ApiServerFault(requestId: 'r', status: 503)), StartupProblemKind.serverError);
      expect(kind(const ApiServerFault(requestId: 'r', status: 200)), StartupProblemKind.invalidResponse);
      expect(
        kind(const ApiRejected(requestId: 'r', status: 404, code: 'HTTP_404', context: <String, Object?>{})),
        StartupProblemKind.invalidResponse,
      );
    });

    test('startup problems from exceptions', () {
      expect(StartupProblem.fromError(const ConfigurationProblem('x')).kind, StartupProblemKind.configuration);
      expect(StartupProblem.fromError(PlatformException(code: 'Exception encountered')).kind, StartupProblemKind.storage);
      expect(StartupProblem.fromError(StateError('x')).kind, StartupProblemKind.unknown);
    });
  });

  group('sign-in isolation between servers', () {
    test('a sign-in made on another server is forgotten', () async {
      final SettingsStore settings = await _settings(<String, Object>{'session_server': 'http://10.0.2.2:8000/api/v1'});
      final MemorySecretStore secrets = MemorySecretStore()
        ..values.addAll(<String, String>{'token': 'gcp_dev', 'profile': '{}', 'device_id': 'd'});
      final bool dropped = await forgetSessionOfOtherServer(
        settings: settings,
        secrets: secrets,
        apiBaseUrl: 'https://app.giftcardpro.at/api/v1',
      );
      expect(dropped, isTrue);
      expect(secrets.values.keys, <String>['device_id']);
      expect(settings.sessionServer, 'https://app.giftcardpro.at/api/v1');
    });

    test('the same server, or no record yet, keeps the sign-in', () async {
      final SettingsStore settings = await _settings();
      final MemorySecretStore secrets = MemorySecretStore()..values['token'] = 'gcp_prod';
      expect(await forgetSessionOfOtherServer(settings: settings, secrets: secrets, apiBaseUrl: 'https://a.at/api/v1'), isFalse);
      expect(await forgetSessionOfOtherServer(settings: settings, secrets: secrets, apiBaseUrl: 'https://a.at/api/v1'), isFalse);
      expect(secrets.values['token'], 'gcp_prod');
    });
  });
}
