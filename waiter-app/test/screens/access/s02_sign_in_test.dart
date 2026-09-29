import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/s02_sign_in.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'access_support.dart';

Finder get _email => find.byType(TextField).at(0);
Finder get _password => find.byType(TextField).at(1);
Finder get _submit => find.byType(PrimaryButton);

bool _enabled(WidgetTester tester) => tester.widget<PrimaryButton>(_submit).onPressed != null;

String _label(WidgetTester tester) => tester.widget<PrimaryButton>(_submit).label;

Future<void> _fill(WidgetTester tester, {String email = 'anna@example.at', String password = 'secret'}) async {
  await tester.enterText(_email, email);
  await tester.enterText(_password, password);
  await tester.pump();
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.tap(_submit);
  await settle(tester);
}

void main() {
  testWidgets('renders the form; the button needs both fields', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    await pumpWaiterApp(tester, app);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(text(en.signInSubtitle), findsOneWidget);
    expect(text(en.signInEmailLabel), findsOneWidget);
    expect(text(en.signInPasswordLabel), findsOneWidget);
    expect(text(en.signInForgot), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(_enabled(tester), isFalse);

    await tester.enterText(_email, 'anna@example.at');
    await tester.pump();
    expect(_enabled(tester), isFalse);
    await tester.enterText(_password, 'secret');
    await tester.pump();
    expect(_enabled(tester), isTrue);
    await finishApp(tester, app);
  });

  testWidgets('success sends the credentials and leaves S02', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend
      ..on('POST', '/auth/token', FakeReply(201, Payloads.token()))
      ..on('GET', '/auth/me', meReply());
    await pumpWaiterApp(tester, app);

    await _fill(tester, email: ' anna@example.at ');
    await _tapSubmit(tester);

    final RecordedRequest request = app.backend.to('POST', '/auth/token').single;
    expect(request.body!['email'], 'anna@example.at');
    expect(request.body!['password'], 'secret');
    expect(app.session.phase, AccessPhase.active);
    await settle(tester);
    expect(find.byType(SignInScreen), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets('first sign-in with enrolled biometrics goes to S03', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false, biometricsOffered: false);
    app.backend.on('POST', '/auth/token', FakeReply(201, Payloads.token()));
    await pumpWaiterApp(tester, app);

    await _fill(tester);
    await _tapSubmit(tester);
    expect(app.session.phase, AccessPhase.onboardingBiometrics);
    await finishApp(tester, app);
  });

  testWidgets('shows the spinner and the busy label while signing in', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend.on('POST', '/auth/token', FakeReply(201, Payloads.token(), const Duration(seconds: 1)));
    await pumpWaiterApp(tester, app);

    await _fill(tester);
    await tester.tap(_submit);
    await tester.pump(const Duration(milliseconds: 200));
    final PrimaryButton button = tester.widget<PrimaryButton>(_submit);
    expect(button.status, ButtonStatus.loading);
    expect(button.semanticLabel, en.signInLoading);
    await settle(tester, 30);
    await finishApp(tester, app);
  });

  testWidgets('A07: wrong credentials clear only the password and shake it', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend.on('POST', '/auth/token', FakeReply(401, Payloads.error('UNAUTHENTICATED')));
    await pumpWaiterApp(tester, app);

    await _fill(tester);
    await _tapSubmit(tester);

    expect(text(en.signInErrorInvalid), findsOneWidget);
    expect(tester.widget<TextField>(_email).controller!.text, 'anna@example.at');
    expect(tester.widget<TextField>(_password).controller!.text, isEmpty);
    expect(tester.widget<TextField>(_password).focusNode!.hasFocus, isTrue);
    expect(app.session.phase, AccessPhase.signedOut);

    // banner-out on the next edit.
    await tester.enterText(_password, 'x');
    await settle(tester);
    expect(text(en.signInErrorInvalid), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets('e-mail format is checked on blur and on submit, never while typing', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    await pumpWaiterApp(tester, app);

    await tester.enterText(_email, 'anna.example.at');
    await settle(tester);
    expect(text(en.signInErrorEmailFormat), findsNothing);

    // Blur after a value was entered.
    await tester.enterText(_password, 'secret');
    await settle(tester);
    expect(text(en.signInErrorEmailFormat), findsOneWidget);

    await _tapSubmit(tester);
    expect(text(en.signInErrorEmailFormat), findsOneWidget);
    expect(app.backend.to('POST', '/auth/token'), isEmpty);

    await tester.enterText(_email, 'anna@example.at');
    await settle(tester);
    expect(text(en.signInErrorEmailFormat), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets('A02: an account without redeem permission gets the danger banner', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend.on('POST', '/auth/token', FakeReply(403, Payloads.error('FORBIDDEN')));
    await pumpWaiterApp(tester, app);

    await _fill(tester);
    await _tapSubmit(tester);
    expect(text(en.signInErrorNoPermission), findsOneWidget);
    expect(_enabled(tester), isTrue);
    await finishApp(tester, app);
  });

  testWidgets('A08: 429 counts down live and re-enables the button at 0', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend.on(
      'POST',
      '/auth/token',
      FakeReply(429, Payloads.error('TOO_MANY_REQUESTS', <String, Object?>{'retry_after': 3})),
    );
    await pumpWaiterApp(tester, app);

    await _fill(tester);
    await _tapSubmit(tester);
    expect(text(en.signInErrorThrottled('0:03')), findsOneWidget);
    expect(_label(tester), en.signInRetryIn('0:03'));
    expect(_enabled(tester), isFalse);

    await tester.pump(const Duration(seconds: 1));
    expect(text(en.signInErrorThrottled('0:02')), findsOneWidget);
    expect(_label(tester), en.signInRetryIn('0:02'));

    // Editing a field keeps the countdown.
    await tester.enterText(_password, 'secret2');
    await tester.pump();
    expect(text(en.signInErrorThrottled('0:02')), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(find.textContaining('Too many attempts', findRichText: true), findsNothing);
    expect(_label(tester), en.signInSubmit);
    expect(_enabled(tester), isTrue);
    await finishApp(tester, app);
  });

  testWidgets('A09: server error shows the banner and keeps the button', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend.on('POST', '/auth/token', FakeReply(503));
    await pumpWaiterApp(tester, app);

    await _fill(tester);
    await _tapSubmit(tester);
    expect(text(en.signInErrorServer), findsOneWidget);
    // 12 §2.5: the support code of the failed request.
    expect(find.textContaining(RegExp(r'^Code [0-9A-F]{6}$'), findRichText: true), findsOneWidget);
    expect(_enabled(tester), isTrue);
    await finishApp(tester, app);
  });

  testWidgets('A09: offline disables the button and clears on reconnect', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    await pumpWaiterApp(tester, app);
    await _fill(tester);

    app.connectivity.setOnline(false);
    await settle(tester);
    expect(text(en.offlineTitle), findsOneWidget);
    expect(text(en.signInOfflineBody), findsOneWidget);
    expect(_enabled(tester), isFalse);

    app.connectivity.setOnline(true);
    await settle(tester);
    expect(text(en.offlineTitle), findsNothing);
    expect(_enabled(tester), isTrue);
    await finishApp(tester, app);
  });

  testWidgets('a transport failure during the attempt shows the offline banner', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend.on('POST', '/auth/token', FakeReply.transport());
    await pumpWaiterApp(tester, app);

    await _fill(tester);
    await _tapSubmit(tester);
    expect(text(en.signInOfflineBody), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('S4: a locked account gets the same answer as wrong credentials, never a lock screen', (
    WidgetTester tester,
  ) async {
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend.on(
      'POST',
      '/auth/token',
      FakeReply(422, <String, Object?>{
        'message': 'The e-mail address or password is incorrect.',
        'code': 'VALIDATION_FAILED',
        'errors': <String, Object?>{
          'email': <String>['The e-mail address or password is incorrect.'],
        },
      }),
    );
    await pumpWaiterApp(tester, app);

    await _fill(tester);
    await _tapSubmit(tester);
    expect(app.session.blocked, isNull);
    expect(app.session.phase, AccessPhase.signedOut);
    expect(text(en.signInErrorInvalid), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('prefills the last e-mail and focuses the password', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(
      signedIn: false,
      prefs: const <String, Object>{'last_email': 'anna@example.at'},
    );
    await pumpWaiterApp(tester, app);

    expect(tester.widget<TextField>(_email).controller!.text, 'anna@example.at');
    expect(tester.widget<TextField>(_password).focusNode!.hasFocus, isTrue);
    await finishApp(tester, app);
  });

  testWidgets('"Forgot password" opens the web reset page in the in-app browser', (WidgetTester tester) async {
    final List<Map<Object?, Object?>> launches = recordLaunches();
    final TestApp app = await TestApp.create(signedIn: false);
    await pumpWaiterApp(tester, app);

    await tester.enterText(_email, 'anna@example.at');
    await tester.tap(text(en.signInForgot));
    await settle(tester);

    expect(launches.single['url'], 'https://cards.example.at/forgot-password');
    expect(launches.single['useSafariVC'], isTrue);
    expect(tester.widget<TextField>(_email).controller!.text, 'anna@example.at');
    await finishApp(tester, app);
  });

  testWidgets('semantics: heading, field labels and the busy-free button', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final TestApp app = await TestApp.create(signedIn: false);
    await pumpWaiterApp(tester, app);

    expect(tester.getSemantics(text(en.signInTitle).first), matchesSemantics(label: en.signInTitle, isHeader: true));
    expect(find.bySemanticsLabel(en.signInEmailLabel), findsWidgets);
    expect(find.bySemanticsLabel(en.signInPasswordLabel), findsWidgets);
    semantics.dispose();
    await finishApp(tester, app);
  });

  for (final (Locale locale, String title) in <(Locale, String)>[
    (const Locale('de'), 'Anmelden'),
    (const Locale('bs'), 'Prijava'),
    (const Locale('en'), 'Sign in'),
  ]) {
    testWidgets('renders in ${locale.languageCode}', (WidgetTester tester) async {
      final TestApp app = await TestApp.create(signedIn: false);
      await pumpWaiterApp(tester, app, locale: locale);
      final AppLocalizations l = lookupAppLocalizations(locale);
      expect(text(title), findsWidgets);
      expect(text(l.signInSubtitle), findsOneWidget);
      expect(text(l.signInForgot), findsOneWidget);
      await finishApp(tester, app);
    });
  }

  testWidgets('200 % text on the compact frame: no overflow, button above the keyboard', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend.on('POST', '/auth/token', FakeReply(401, Payloads.error('UNAUTHENTICATED')));
    await pumpWaiterApp(tester, app, size: const Size(375, 667));

    await _fill(tester);
    await _tapSubmit(tester);
    expect(tester.takeException(), isNull);
    expect(text(en.signInErrorInvalid), findsOneWidget);

    tester.view.viewInsets = FakeViewPadding(bottom: 300 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getBottomLeft(_submit).dy, lessThanOrEqualTo(667 - 300 - 16 + 0.5));
    await finishApp(tester, app);
  });

  testWidgets('brand row on regular height only; compact button is 56; dark theme', (WidgetTester tester) async {
    final Finder mark = find.byWidgetPredicate((Widget w) => w is WaiterIconView && w.icon == WaiterIcon.cardArcs);
    final TestApp app = await TestApp.create(signedIn: false, prefs: const <String, Object>{'theme': 'dark'});
    await pumpWaiterApp(tester, app);
    expect(mark, findsOneWidget);
    expect(tester.getSize(_submit).height, 64);
    await finishApp(tester, app);

    final TestApp compact = await TestApp.create(signedIn: false, prefs: const <String, Object>{'theme': 'dark'});
    await pumpWaiterApp(tester, compact, size: const Size(375, 667));
    expect(mark, findsNothing);
    expect(tester.getSize(_submit).height, 56);
    final ColoredBox canvas = tester.widget<ColoredBox>(
      find.descendant(of: find.byType(SignInScreen), matching: find.byType(ColoredBox)).first,
    );
    expect(canvas.color, const Color(0xFF0A0A0C));
    expect(tester.takeException(), isNull);
    await finishApp(tester, compact);
  });
}
