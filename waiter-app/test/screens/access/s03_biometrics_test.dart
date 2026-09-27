import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/s03_biometrics.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'access_support.dart';

/// Signs in for the first time on this install, which offers S03.
Future<TestApp> _openS03(
  WidgetTester tester, {
  bool isIos = false,
  List<BiometricType>? types,
  bool introDone = true,
  Locale locale = const Locale('en'),
  Size size = const Size(393, 852),
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  final TestApp app = await TestApp.create(
    signedIn: false,
    biometricsOffered: false,
    isIos: isIos,
    introDone: introDone,
    prefs: prefs,
  );
  if (types != null) {
    when(app.localAuth.getAvailableBiometrics).thenAnswer((_) async => types);
  }
  app.backend
    ..on('POST', '/auth/token', FakeReply(201, Payloads.token()))
    ..on('GET', '/auth/me', meReply());
  await pumpWaiterApp(tester, app, locale: locale, size: size);
  await tester.enterText(find.byType(TextField).at(0), 'anna@example.at');
  await tester.enterText(find.byType(TextField).at(1), 'secret');
  await tester.pump();
  await tester.tap(find.byType(PrimaryButton));
  await settle(tester);
  expect(find.byType(EnableBiometricsScreen), findsOneWidget);
  return app;
}

int _haptics(TestApp app) => app.feedbackCalls.where((MethodCall c) => c.method == 'haptic').length;

Finder _icon(WaiterIcon icon) => find.byWidgetPredicate((Widget w) => w is WaiterIconView && w.icon == icon);

void main() {
  setUpAll(registerAuthFallbacks);

  testWidgets('Android variant: fingerprint glyph and biometrics strings', (WidgetTester tester) async {
    final TestApp app = await _openS03(tester);
    expect(text(en.biometricsTitleAndroid), findsOneWidget);
    expect(text(en.biometricsBody), findsOneWidget);
    expect(text(en.biometricsEnableAndroid), findsOneWidget);
    expect(text(en.biometricsNotNow), findsOneWidget);
    expect(_icon(WaiterIcon.fingerprint), findsWidgets);
    await finishApp(tester, app);
  });

  testWidgets('iPhone Face ID variant', (WidgetTester tester) async {
    final TestApp app = await _openS03(tester, isIos: true, types: <BiometricType>[BiometricType.face]);
    expect(text(en.biometricsTitleFaceId), findsOneWidget);
    expect(text(en.biometricsEnableFaceId), findsOneWidget);
    expect(_icon(WaiterIcon.scanFace), findsWidgets);
    await finishApp(tester, app);
  });

  testWidgets('iPhone Touch ID variant', (WidgetTester tester) async {
    final TestApp app = await _openS03(tester, isIos: true, types: <BiometricType>[BiometricType.fingerprint]);
    expect(text(en.biometricsTitleTouchId), findsOneWidget);
    expect(text(en.biometricsEnableTouchId), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('enabling succeeds and continues to the intro on the first run', (WidgetTester tester) async {
    final TestApp app = await _openS03(tester, introDone: false);
    stubPrompt(app, () async => true);
    await tester.tap(find.byType(PrimaryButton));
    await settle(tester);
    expect(app.services.settings.biometricsEnabled, isTrue);
    expect(app.session.phase, AccessPhase.onboardingIntro);
    await finishApp(tester, app);
  });

  testWidgets('P11: a cancelled prompt shows the caption and never re-prompts', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final TestApp app = await _openS03(tester);
    int prompts = 0;
    stubPrompt(app, () async {
      prompts++;
      return false;
    });
    final int before = _haptics(app);
    await tester.tap(find.byType(PrimaryButton));
    await settle(tester);

    expect(text(en.biometricsFailed), findsOneWidget);
    expect(_haptics(app), before + 1);
    expect(app.session.phase, AccessPhase.onboardingBiometrics);
    await settle(tester, 20);
    expect(prompts, 1);

    // A new tap prompts again.
    await tester.tap(find.byType(PrimaryButton));
    await settle(tester);
    expect(prompts, 2);
    semantics.dispose();
    await finishApp(tester, app);
  });

  testWidgets('P10: nothing enrolled shows the snackbar', (WidgetTester tester) async {
    final TestApp app = await _openS03(tester);
    stubPrompt(app, () async => throw const LocalAuthException(code: LocalAuthExceptionCode.noBiometricsEnrolled));
    await tester.tap(find.byType(PrimaryButton));
    await settle(tester);
    expect(text(en.biometricsNotEnrolledAndroid), findsOneWidget);
    expect(text(en.biometricsFailed), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await finishApp(tester, app);
  });

  testWidgets('"Not now" continues without biometrics', (WidgetTester tester) async {
    final TestApp app = await _openS03(tester);
    await tester.tap(text(en.biometricsNotNow));
    await settle(tester);
    expect(app.services.settings.biometricsEnabled, isFalse);
    expect(app.services.settings.biometricsOffered, isTrue);
    expect(app.session.phase, AccessPhase.active);
    await finishApp(tester, app);
  });

  testWidgets('both buttons are inert while the OS prompt is up', (WidgetTester tester) async {
    final TestApp app = await _openS03(tester);
    int prompts = 0;
    stubPrompt(app, () async {
      prompts++;
      await Future<void>.delayed(const Duration(seconds: 2));
      return false;
    });
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
    await tester.tap(text(en.biometricsNotNow), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 100));
    expect(prompts, 1);
    expect(app.session.phase, AccessPhase.onboardingBiometrics);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    await finishApp(tester, app);
  });

  testWidgets('semantics: title heading, glyph hidden', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final TestApp app = await _openS03(tester);
    expect(
      tester.getSemantics(text(en.biometricsTitleAndroid)),
      matchesSemantics(label: en.biometricsTitleAndroid, isHeader: true),
    );
    semantics.dispose();
    await finishApp(tester, app);
  });

  testWidgets('German, compact frame, 200 % text and dark theme without overflow', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final AppLocalizations de = lookupAppLocalizations(const Locale('de'));
    final TestApp app = await _openS03(
      tester,
      locale: const Locale('de'),
      size: const Size(375, 667),
      prefs: const <String, Object>{'theme': 'dark'},
    );
    expect(text(de.biometricsTitleAndroid), findsOneWidget);
    expect(tester.takeException(), isNull);
    // Buttons stay pinned at the bottom.
    expect(tester.getBottomLeft(find.byType(TertiaryButton)).dy, closeTo(667 - 20, 0.5));
    await finishApp(tester, app);
  });

  testWidgets('BHS strings on the compact frame', (WidgetTester tester) async {
    final AppLocalizations bs = lookupAppLocalizations(const Locale('bs'));
    final TestApp app = await _openS03(tester, locale: const Locale('bs'), size: const Size(375, 667));
    expect(text(bs.biometricsBody), findsOneWidget);
    expect(text(bs.biometricsNotNow), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finishApp(tester, app);
  });

  testWidgets('compact height: 72-pt plate, 56-pt button', (WidgetTester tester) async {
    final TestApp app = await _openS03(tester, size: const Size(375, 667));
    expect(tester.getSize(find.byType(PrimaryButton)).height, 56);
    final Finder plate = find.ancestor(of: _icon(WaiterIcon.fingerprint).first, matching: find.byType(Container));
    expect(tester.getSize(plate.first), const Size(72, 72));
    await finishApp(tester, app);
  });
}
