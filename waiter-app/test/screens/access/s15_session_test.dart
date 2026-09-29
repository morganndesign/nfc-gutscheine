import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/s02_sign_in.dart';
import 'package:giftcard_waiter/screens/s15_session.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'access_support.dart';

/// A signed-in start whose background `GET /auth/me` answers with [me].
Future<TestApp> _startWith(
  WidgetTester tester,
  FakeReply me, {
  List<FakeReply> later = const <FakeReply>[],
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  final TestApp app = await TestApp.create(prefs: <String, Object>{'last_email': 'anna@example.at', ...prefs});
  app.backend.on('GET', '/auth/me', me);
  for (final FakeReply reply in later) {
    app.backend.on('GET', '/auth/me', reply);
  }
  await pumpWaiterApp(tester, app, locale: locale, size: size);
  return app;
}

Finder get _sheetPassword => find.descendant(of: find.byType(SessionExpiredSheet), matching: find.byType(TextField));

Finder get _sheetButton => find.descendant(of: find.byType(SessionExpiredSheet), matching: find.byType(PrimaryButton));

void main() {
  group('10.1 session expired sheet', () {
    testWidgets('a 401 opens the sheet; signing in again closes it', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final TestApp app = await _startWith(tester, FakeReply(401, Payloads.error('UNAUTHENTICATED')));
      app.backend.on('POST', '/auth/token', FakeReply(201, Payloads.token()));
      await settle(tester);

      expect(find.byType(SessionExpiredSheet), findsOneWidget);
      expect(text(en.sessionExpired), findsOneWidget);
      expect(text(en.sessionExpiredBody), findsOneWidget);
      expect(text('anna@example.at'), findsOneWidget);
      expect(find.bySemanticsLabel('${en.signInEmailLabel}, anna@example.at'), findsOneWidget);
      // Not dismissible: no ✕.
      expect(find.byWidgetPredicate((Widget w) => w is WaiterIconButton && w.icon == WaiterIcon.x), findsNothing);
      expect(tester.widget<PrimaryButton>(_sheetButton).onPressed, isNull);

      // Android back does nothing while the sheet is up.
      unawaited(tester.binding.handlePopRoute());
      await settle(tester);
      expect(find.byType(SessionExpiredSheet), findsOneWidget);
      expect(app.session.expired, isNotNull);

      await tester.enterText(_sheetPassword, 'secret');
      await tester.pump();
      await tester.tap(_sheetButton);
      await settle(tester);

      expect(app.backend.to('POST', '/auth/token').single.body!['email'], 'anna@example.at');
      expect(app.session.expired, isNull);
      await settle(tester);
      expect(find.byType(SessionExpiredSheet), findsNothing);
      semantics.dispose();
      await finishApp(tester, app);
    });

    testWidgets('wrong password: banner, password cleared, sheet stays', (WidgetTester tester) async {
      final TestApp app = await _startWith(tester, FakeReply(401, Payloads.error('UNAUTHENTICATED')));
      app.backend.on('POST', '/auth/token', FakeReply(401, Payloads.error('UNAUTHENTICATED')));
      await settle(tester);

      await tester.enterText(_sheetPassword, 'wrong');
      await tester.pump();
      await tester.tap(_sheetButton);
      await settle(tester);

      expect(text(en.signInErrorInvalid), findsOneWidget);
      expect(tester.widget<TextField>(_sheetPassword).controller!.text, isEmpty);
      expect(find.byType(SessionExpiredSheet), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('429 on the sheet counts down on the button', (WidgetTester tester) async {
      final TestApp app = await _startWith(tester, FakeReply(401, Payloads.error('UNAUTHENTICATED')));
      app.backend.on(
        'POST',
        '/auth/token',
        FakeReply(429, Payloads.error('TOO_MANY_REQUESTS', <String, Object?>{'retry_after': 2})),
      );
      await settle(tester);
      await tester.enterText(_sheetPassword, 'secret');
      await tester.pump();
      await tester.tap(_sheetButton);
      await settle(tester);

      expect(tester.widget<PrimaryButton>(_sheetButton).label, en.signInRetryIn('0:02'));
      expect(tester.widget<PrimaryButton>(_sheetButton).onPressed, isNull);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(tester.widget<PrimaryButton>(_sheetButton).label, en.sessionExpiredAction);
      expect(tester.widget<PrimaryButton>(_sheetButton).onPressed, isNotNull);
      await finishApp(tester, app);
    });

    testWidgets('German, 200 % text, compact, dark: no overflow', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final AppLocalizations de = lookupAppLocalizations(const Locale('de'));
      final TestApp app = await _startWith(
        tester,
        FakeReply(401, Payloads.error('UNAUTHENTICATED')),
        locale: const Locale('de'),
        size: const Size(375, 667),
        prefs: const <String, Object>{'theme': 'dark'},
      );
      await settle(tester);
      expect(text(de.sessionExpired), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });
  });

  group('full-screen states', () {
    testWidgets('A04 device revoked: support code, "Sign in" leads to S02', (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      final TestApp app = await _startWith(tester, FakeReply(403, Payloads.error('DEVICE_REVOKED')));
      await settle(tester);

      expect(find.byType(BlockedScreen), findsOneWidget);
      expect(text(en.deviceRevokedTitle), findsOneWidget);
      expect(text(en.deviceRevokedBody), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Code [0-9A-F]{6}$'), findRichText: true), findsOneWidget);
      expect(
        tester.getSemantics(text(en.deviceRevokedTitle)),
        matchesSemantics(label: en.deviceRevokedTitle, isHeader: true),
      );

      await tester.tap(text(en.deviceRevokedAction));
      await settle(tester);
      expect(app.session.phase, AccessPhase.signedOut);
      expect(find.byType(SignInScreen), findsOneWidget);
      semantics.dispose();
      await finishApp(tester, app);
    });

    testWidgets('A05 suspended: "Check again" returns to Ready when active again', (WidgetTester tester) async {
      final TestApp app = await _startWith(
        tester,
        FakeReply(403, Payloads.error('RESTAURANT_SUSPENDED')),
        later: <FakeReply>[meReply()],
      );
      await settle(tester);
      expect(text(en.suspendedTitle), findsOneWidget);
      expect(text(en.menuSignOut), findsOneWidget);

      await tester.tap(text(en.commonCheckAgain));
      await settle(tester);
      expect(app.session.phase, AccessPhase.active);
      await finishApp(tester, app);
    });

    testWidgets('A05: "Check again" without a connection shows the offline caption', (WidgetTester tester) async {
      final TestApp app = await _startWith(
        tester,
        FakeReply(403, Payloads.error('RESTAURANT_SUSPENDED')),
        later: <FakeReply>[FakeReply.transport()],
      );
      await settle(tester);
      expect(text(en.offlineTitle), findsNothing);
      await tester.tap(text(en.commonCheckAgain));
      await settle(tester);
      expect(text(en.offlineTitle), findsOneWidget);
      expect(text(en.suspendedTitle), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('long-press on the support code copies the full request id', (WidgetTester tester) async {
      final List<String> copied = <String>[];
      final TestDefaultBinaryMessenger messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map<Object?, Object?>)['text']! as String);
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final TestApp app = await _startWith(tester, FakeReply(403, Payloads.error('DEVICE_REVOKED')));
      await settle(tester);
      await tester.longPress(find.textContaining(RegExp(r'^Code '), findRichText: true));
      await settle(tester);
      final String id = app.backend.to('GET', '/auth/me').last.header('X-Request-Id')!;
      expect(copied, <String>[id]);
      await tester.pump(const Duration(seconds: 5));
      await finishApp(tester, app);
    });

    testWidgets('A05: "Check again" at most once per 3 s; "Sign out" leads to S02', (WidgetTester tester) async {
      final TestApp app = await _startWith(tester, FakeReply(403, Payloads.error('RESTAURANT_SUSPENDED')));
      await settle(tester);
      final int before = app.backend.to('GET', '/auth/me').length;

      await tester.tap(text(en.commonCheckAgain));
      await settle(tester);
      await tester.tap(text(en.commonCheckAgain));
      await settle(tester);
      expect(app.backend.to('GET', '/auth/me').length, before + 1);
      expect(text(en.suspendedTitle), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      await tester.tap(text(en.commonCheckAgain));
      await settle(tester);
      expect(app.backend.to('GET', '/auth/me').length, before + 2);

      await tester.tap(text(en.menuSignOut));
      await settle(tester);
      expect(app.session.phase, AccessPhase.signedOut);
      await finishApp(tester, app);
    });

    testWidgets('A03 forbidden: check again and back to sign in', (WidgetTester tester) async {
      final TestApp app = await _startWith(tester, FakeReply(403, Payloads.error('FORBIDDEN')));
      await settle(tester);
      expect(text(en.forbiddenTitle), findsOneWidget);
      expect(text(en.forbiddenBody), findsOneWidget);
      expect(text(en.commonCheckAgain), findsOneWidget);

      await tester.tap(text(en.commonBackToSignIn));
      await settle(tester);
      expect(app.session.phase, AccessPhase.signedOut);
      await finishApp(tester, app);
    });

    testWidgets('A10 deactivated: back to sign in', (WidgetTester tester) async {
      final TestApp app = await _startWith(tester, FakeReply(401, Payloads.error('ACCOUNT_DEACTIVATED')));
      await settle(tester);
      expect(text(en.deactivatedTitle), findsOneWidget);
      expect(text(en.deactivatedBody), findsOneWidget);

      await tester.tap(text(en.commonBackToSignIn));
      await settle(tester);
      expect(find.byType(SignInScreen), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('BHS and 200 % text on the compact frame', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final AppLocalizations bs = lookupAppLocalizations(const Locale('bs'));
      final TestApp app = await _startWith(
        tester,
        FakeReply(403, Payloads.error('RESTAURANT_SUSPENDED')),
        locale: const Locale('bs'),
        size: const Size(375, 667),
      );
      await settle(tester);
      expect(text(bs.suspendedTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await finishApp(tester, app);
    });
  });

  group('10.6 update required', () {
    Future<TestApp> updateRequired(WidgetTester tester, {bool isIos = false}) async {
      final TestApp app = await TestApp.create(signedIn: false, isIos: isIos);
      app.backend.on('GET', '/app/config', FakeReply(200, Payloads.config(updateRequired: true)));
      await pumpWaiterApp(tester, app);
      // The next /app/config check (after 5 min, on foreground) finds the minimum version.
      await tester.pump(const Duration(minutes: 6));
      unawaited(app.session.onForeground());
      await settle(tester);
      expect(app.session.phase, AccessPhase.updateRequired);
      return app;
    }

    testWidgets('Android opens the Play listing of the package', (WidgetTester tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'GiftCard Waiter',
        packageName: 'at.example.waiter',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      final List<Map<Object?, Object?>> launches = recordLaunches();
      final TestApp app = await updateRequired(tester);

      expect(find.byType(UpdateRequiredScreen), findsOneWidget);
      expect(text(en.updateTitle), findsOneWidget);
      expect(text(en.updateBody), findsOneWidget);
      await tester.tap(text(en.updateAction));
      await settle(tester);
      expect(launches.single['url'], 'https://play.google.com/store/apps/details?id=at.example.waiter');
      expect(launches.single['useSafariVC'], isFalse);
      // The button stays; nothing else happens.
      expect(find.byType(UpdateRequiredScreen), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('iPhone without a configured App Store URL opens nothing', (WidgetTester tester) async {
      final List<Map<Object?, Object?>> launches = recordLaunches();
      final TestApp app = await updateRequired(tester, isIos: true);
      await tester.tap(text(en.updateAction));
      await settle(tester);
      expect(launches, isEmpty);
      expect(find.byType(UpdateRequiredScreen), findsOneWidget);
      await finishApp(tester, app);
    });
  });
}
