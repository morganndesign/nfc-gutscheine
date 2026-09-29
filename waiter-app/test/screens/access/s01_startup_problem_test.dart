import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/app/startup_failure_app.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/config/environment.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/core/state/startup_problem.dart';
import 'package:giftcard_waiter/screens/s01_startup_problem.dart';
import 'package:giftcard_waiter/screens/s02_sign_in.dart';
import 'package:giftcard_waiter/screens/s05_ready.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'access_support.dart';

const AppEnvironment _production = AppEnvironment(apiBaseUrl: 'https://app.giftcardpro.at/api/v1');

final AppEnvironment _development = AppEnvironment.resolve(<String, String>{
  'APP_ENV': 'development',
  'API_BASE_URL': 'http://10.0.2.2:8000/api/v1',
});

void main() {
  group('S01 · startup problem instead of an endless splash', () {
    testWidgets('unregistered domain: "Server not found" with the host, then Try again', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(signedIn: false, environment: _production);
      app.backend.only('GET', '/app/config', FakeReply.dns());
      await pumpWaiterApp(tester, app);

      expect(app.session.phase, AccessPhase.startupProblem);
      expect(find.byType(StartupProblemScreen), findsOneWidget);
      expect(text(en.startupHostNotFoundTitle), findsOneWidget);
      expect(text(en.startupHostNotFoundBody('app.giftcardpro.at')), findsOneWidget);
      expect(find.textContaining('Server: https://app.giftcardpro.at/api/v1', findRichText: true), findsOneWidget);
      expect(find.textContaining("Failed host lookup: 'app.giftcardpro.at'", findRichText: true), findsOneWidget);
      expect(text(en.startupChangeServer), findsNothing, reason: 'production builds cannot change the server');

      // The server comes up: Try again reaches sign in.
      app.backend.only('GET', '/app/config', FakeReply(200, Payloads.config()));
      await tester.tap(text(en.commonTryAgain));
      await settle(tester);
      expect(app.session.phase, AccessPhase.signedOut);
      expect(find.byType(SignInScreen), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('server not started (connection refused)', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(signedIn: false, environment: _development);
      app.backend.only('GET', '/app/config', FakeReply.refused());
      await pumpWaiterApp(tester, app);
      expect(text(en.startupRefusedTitle), findsOneWidget);
      expect(text(en.startupRefusedBody('10.0.2.2:8000')), findsOneWidget);
      expect(find.textContaining(en.startupEnvironment(en.envDevelopment), findRichText: true), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('something else answers (404 / HTML): "Wrong server address"', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(signedIn: false);
      app.backend.only('GET', '/app/config', FakeReply(404));
      await pumpWaiterApp(tester, app);
      expect(text(en.startupInvalidResponseTitle), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('5xx: "Server problem" with the status', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(signedIn: false);
      app.backend.only('GET', '/app/config', FakeReply(503));
      await pumpWaiterApp(tester, app);
      expect(text(en.startupServerErrorTitle), findsOneWidget);
      expect(text(en.startupServerErrorBody('cards.example.at', '503')), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('no answer within 2 s: "Server not responding"', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(signedIn: false);
      app.backend.only('GET', '/app/config', FakeReply.hang(const Duration(seconds: 30)));
      await pumpWaiterApp(tester, app);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(text(en.startupTimeoutTitle), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('offline phone: the offline copy, retried when the network returns', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(signedIn: false);
      app.backend.only('GET', '/app/config', FakeReply.transport());
      app.connectivity.setOnline(false);
      await pumpWaiterApp(tester, app);
      expect(text(en.startupOfflineTitle), findsOneWidget);

      app.backend.only('GET', '/app/config', FakeReply(200, Payloads.config()));
      app.connectivity.setOnline(true);
      await settle(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('a signed-in waiter is not blocked by an unreachable server (offline handling of S05)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await TestApp.create(environment: _production);
      app.backend.only('GET', '/app/config', FakeReply.dns());
      app.backend.on('GET', '/auth/me', FakeReply.dns());
      await pumpWaiterApp(tester, app);
      expect(app.session.phase, AccessPhase.active);
      expect(find.byType(ReadyScreen), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('an exception during the launch decision ends on the problem screen', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(signedIn: false);
      when(app.localAuth.isDeviceSupported).thenThrow(StateError('platform channel broke'));
      await pumpWaiterApp(tester, app);
      expect(app.session.phase, AccessPhase.startupProblem);
      expect(text(en.startupUnknownTitle), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('a launch that never decides shows the problem after 20 s', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(signedIn: false);
      final Completer<bool> never = Completer<bool>();
      when(app.localAuth.isDeviceSupported).thenAnswer((_) => never.future);
      await pumpWaiterApp(tester, app);
      expect(app.session.phase, AccessPhase.launching);
      await tester.pump(const Duration(seconds: 21));
      await settle(tester);
      expect(app.session.phase, AccessPhase.startupProblem);
      expect(text(en.startupUnknownTitle), findsOneWidget);
      await finishApp(tester, app);
    });
  });

  group('development and staging builds: server address', () {
    testWidgets('Change server: saving connects to the new server', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(signedIn: false, environment: _development);
      app.backend.only('GET', '/app/config', FakeReply.refused());
      await pumpWaiterApp(tester, app);
      expect(text(en.startupChangeServer), findsOneWidget);

      await tester.tap(text(en.startupChangeServer));
      await settle(tester, 20);
      expect(text(en.serverTitle), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'nonsense');
      await tester.tap(text(en.serverSave));
      await settle(tester);
      expect(text(en.serverInvalid), findsOneWidget);

      app.backend.only('GET', '/app/config', FakeReply(200, Payloads.config()));
      await tester.enterText(find.byType(EditableText), 'http://192.168.1.20:8000');
      await tester.tap(text(en.serverSave));
      await settle(tester, 12);

      expect(app.services.environment.apiBaseUrl, 'http://192.168.1.20:8000/api/v1');
      expect(app.services.settings.apiServerOverride, 'http://192.168.1.20:8000/api/v1');
      expect(app.backend.requests.last.path, '/app/config');
      expect(find.byType(SignInScreen), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('the corner badge shows the environment; production has none', (WidgetTester tester) async {
      final TestApp dev = await TestApp.create(signedIn: false, environment: _development);
      await pumpWaiterApp(tester, dev);
      expect(find.byType(EnvironmentBadge), findsOneWidget);
      await tester.longPress(find.byType(EnvironmentBadge));
      await settle(tester);
      expect(text(en.serverTitle), findsOneWidget);
      await finishApp(tester, dev);

      final TestApp prod = await TestApp.create(signedIn: false, environment: _production);
      await pumpWaiterApp(tester, prod);
      expect(find.byType(EnvironmentBadge), findsNothing);
      await finishApp(tester, prod);
    });
  });

  group('StartupFailureApp (bootstrap failed)', () {
    testWidgets('invalid build configuration: reason and Try again', (WidgetTester tester) async {
      int retries = 0;
      await tester.pumpWidget(
        StartupFailureApp(
          problem: StartupProblem.fromError(const ConfigurationProblem('API_BASE_URL is empty')),
          environment: null,
          onRetry: () async => retries++,
        ),
      );
      await settle(tester);
      expect(text(en.startupConfigurationTitle), findsOneWidget);
      expect(find.textContaining('API_BASE_URL is empty', findRichText: true), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton));
      await settle(tester);
      expect(retries, 1);
    });
  });
}
