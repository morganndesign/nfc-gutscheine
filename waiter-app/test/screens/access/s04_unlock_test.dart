import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/platform/channels.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/s02_sign_in.dart';
import 'package:giftcard_waiter/screens/s04_unlock.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'access_support.dart';

/// A signed-in app with biometrics enabled: cold start lands on S04.
Future<TestApp> _locked({bool isIos = false, List<BiometricType>? types}) async {
  final TestApp app = await TestApp.create(
    biometrics: true,
    isIos: isIos,
    prefs: const <String, Object>{'last_email': 'anna@example.at'},
  );
  if (types != null) {
    when(app.localAuth.getAvailableBiometrics).thenAnswer((_) async => types);
  }
  app.backend.on('GET', '/auth/me', meReply());
  return app;
}

void main() {
  setUpAll(registerAuthFallbacks);

  testWidgets('the prompt opens without a tap; success unlocks', (WidgetTester tester) async {
    final TestApp app = await _locked();
    int prompts = 0;
    stubPrompt(app, () async {
      prompts++;
      return true;
    });
    await pumpWaiterApp(tester, app);

    expect(prompts, 1);
    expect(app.session.phase, AccessPhase.active);
    await settle(tester);
    expect(find.byType(UnlockScreen), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets('shows who is unlocking; name and restaurant are read together', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final TestApp app = await _locked();
    stubPrompt(app, () async => false);
    await pumpWaiterApp(tester, app);

    expect(text('Anna Berger'), findsOneWidget);
    expect(text('Trattoria Bella Vista'), findsOneWidget);
    expect(tester.getSize(find.byType(Avatar)), const Size(72, 72));
    // Focus moves to the PrimaryButton once the prompt is dismissed.
    expect(tester.widget<PrimaryButton>(find.byType(PrimaryButton)).focusNode!.hasFocus, isTrue);
    expect(find.bySemanticsLabel('Anna Berger, Trattoria Bella Vista'), findsOneWidget);
    expect(text(en.unlockButtonAndroid), findsOneWidget);
    expect(text(en.unlockUsePassword), findsOneWidget);
    semantics.dispose();
    await finishApp(tester, app);
  });

  testWidgets('P11: a cancelled prompt never re-opens by itself; the button re-prompts', (WidgetTester tester) async {
    final TestApp app = await _locked();
    int prompts = 0;
    stubPrompt(app, () async {
      prompts++;
      return false;
    });
    await pumpWaiterApp(tester, app);

    expect(text(en.biometricsFailed), findsOneWidget);
    await settle(tester, 40);
    expect(prompts, 1);
    expect(app.session.phase, AccessPhase.locked);

    await tester.tap(find.byType(PrimaryButton));
    await settle(tester);
    expect(prompts, 2);
    await finishApp(tester, app);
  });

  testWidgets('returning from the background prompts again', (WidgetTester tester) async {
    final TestApp app = await _locked();
    int prompts = 0;
    stubPrompt(app, () async {
      prompts++;
      return false;
    });
    await pumpWaiterApp(tester, app);
    expect(prompts, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(prompts, 2);
    await finishApp(tester, app);
  });

  testWidgets('P12: lockout shows the password hint', (WidgetTester tester) async {
    final TestApp app = await _locked();
    stubPrompt(app, () async => throw const LocalAuthException(code: LocalAuthExceptionCode.biometricLockout));
    await pumpWaiterApp(tester, app);
    expect(text(en.unlockLockedOut), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('P13: changed biometrics force the password with the S02 notice', (WidgetTester tester) async {
    final TestApp app = await _locked();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      WaiterChannels.system,
      (MethodCall call) async => switch (call.method) {
        'deviceFacts' => <String, Object?>{
          'platform': 'android',
          'osVersion': '14',
          'model': 'Pixel 7',
          'isTablet': false,
        },
        'biometricEnrollment' => 'changed',
        _ => null,
      },
    );
    stubPrompt(app, () async => true);
    await pumpWaiterApp(tester, app);
    await settle(tester);

    expect(app.session.phase, AccessPhase.signedOut);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(text(en.unlockChanged), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'anna@example.at');

    await tester.enterText(find.byType(TextField).at(1), 's');
    await settle(tester);
    expect(text(en.unlockChanged), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets('"Use password" goes to S02 with the e-mail prefilled', (WidgetTester tester) async {
    final TestApp app = await _locked();
    final Completer<bool> prompt = Completer<bool>();
    stubPrompt(app, () => prompt.future);
    await pumpWaiterApp(tester, app);
    prompt.complete(false);
    await settle(tester);

    await tester.tap(text(en.unlockUsePassword));
    await settle(tester);
    expect(app.session.phase, AccessPhase.signedOut);
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'anna@example.at');
    await finishApp(tester, app);
  });

  testWidgets('buttons are inert while the prompt is up', (WidgetTester tester) async {
    final TestApp app = await _locked();
    final Completer<bool> prompt = Completer<bool>();
    int prompts = 0;
    stubPrompt(app, () {
      prompts++;
      return prompt.future;
    });
    await pumpWaiterApp(tester, app);
    await tester.tap(find.byType(PrimaryButton), warnIfMissed: false);
    await tester.tap(text(en.unlockUsePassword), warnIfMissed: false);
    await settle(tester);
    expect(prompts, 1);
    expect(app.session.phase, AccessPhase.locked);
    prompt.complete(false);
    await settle(tester);
    await finishApp(tester, app);
  });

  testWidgets('iPhone Face ID and Touch ID button labels', (WidgetTester tester) async {
    final TestApp face = await _locked(isIos: true, types: <BiometricType>[BiometricType.face]);
    stubPrompt(face, () async => false);
    await pumpWaiterApp(tester, face);
    expect(text(en.unlockButtonFaceId), findsOneWidget);
    await finishApp(tester, face);

    final TestApp touch = await _locked(isIos: true, types: <BiometricType>[BiometricType.fingerprint]);
    stubPrompt(touch, () async => false);
    await pumpWaiterApp(tester, touch);
    expect(text(en.unlockButtonTouchId), findsOneWidget);
    await finishApp(tester, touch);
  });

  testWidgets('German, compact, 200 % text and dark theme without overflow', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final AppLocalizations de = lookupAppLocalizations(const Locale('de'));
    final TestApp app = await TestApp.create(biometrics: true, prefs: const <String, Object>{'theme': 'dark'});
    stubPrompt(app, () async => false);
    await pumpWaiterApp(tester, app, locale: const Locale('de'), size: const Size(375, 667));
    expect(text(de.unlockUsePassword), findsOneWidget);
    expect(text(de.biometricsFailed), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finishApp(tester, app);
  });

  testWidgets('BHS strings on the compact frame', (WidgetTester tester) async {
    final AppLocalizations bs = lookupAppLocalizations(const Locale('bs'));
    final TestApp app = await _locked();
    stubPrompt(app, () async => false);
    await pumpWaiterApp(tester, app, locale: const Locale('bs'), size: const Size(375, 667));
    expect(text(bs.unlockButtonAndroid), findsOneWidget);
    expect(text(bs.unlockUsePassword), findsOneWidget);
    await finishApp(tester, app);
  });
}
