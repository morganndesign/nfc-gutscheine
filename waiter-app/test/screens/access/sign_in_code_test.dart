import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/screens/s02_sign_in.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'access_support.dart';

/// Every app sign-in needs the code from the e-mail (decision 2026-10-06), and
/// every app update signs in again. Android and iPhone alike.
void main() {
  Finder field(String label) => find.descendant(
    of: find.byWidgetPredicate((Widget w) => w is WaiterTextField && w.label == label),
    matching: find.byType(TextField),
  );
  Finder primary(String label) => find.byWidgetPredicate((Widget w) => w is PrimaryButton && w.label == label);

  Future<void> password(WidgetTester tester) async {
    await tester.enterText(field(en.signInEmailLabel), 'anna@example.at');
    await tester.enterText(field(en.signInPasswordLabel), 'secret');
    await tester.pump();
    await tester.tap(primary(en.signInSubmit));
    await settle(tester);
  }

  for (final bool ios in <bool>[false, true]) {
    testWidgets('${ios ? 'iPhone' : 'Android'}: password, then the code from the e-mail signs in', (
      WidgetTester tester,
    ) async {
      final TestApp app = await TestApp.create(isIos: ios, signedIn: false);
      app.backend
        ..on('POST', '/auth/token', FakeReply(202, Payloads.codeChallenge()))
        ..on('POST', '/auth/token/code', FakeReply(201, Payloads.token()))
        ..on('GET', '/auth/me', meReply());
      await pumpWaiterApp(tester, app);

      await password(tester);
      expect(text(en.signInCodeTitle), findsOneWidget);
      expect(text(en.signInCodeBody('a•••@example.at')), findsOneWidget);
      expect(app.session.phase, AccessPhase.signedOut);

      // Six digits confirm at once (also when filled in from the e-mail).
      await tester.enterText(field(en.signInCodeLabel), '123456');
      await settle(tester);

      final RecordedRequest confirm = app.backend.to('POST', '/auth/token/code').single;
      expect(confirm.body!['login'], 'login-1');
      expect(confirm.body!['code'], '123456');
      expect(confirm.body!['device_id'], isNotEmpty);
      expect(app.session.phase, AccessPhase.active);
      expect(app.secrets.values['token'], 'gcp_test');
      expect(app.secrets.values['token_version'], '1.0.0');
      await settle(tester);
      expect(find.byType(SignInScreen), findsNothing);
      await finishApp(tester, app);
    });
  }

  testWidgets('a wrong code stays on the code step; an expired one goes back to the password', (
    WidgetTester tester,
  ) async {
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend
      ..on('POST', '/auth/token', FakeReply(202, Payloads.codeChallenge()))
      ..on(
        'POST',
        '/auth/token/code',
        FakeReply(422, <String, Object?>{
          'code': 'LOGIN_CODE_REJECTED',
          'context': <String, Object?>{'reason': 'wrong'},
        }),
      );
    await pumpWaiterApp(tester, app);
    await password(tester);

    await tester.enterText(field(en.signInCodeLabel), '000000');
    await settle(tester);
    expect(text(en.signInCodeWrong), findsOneWidget);
    expect(text(en.signInCodeTitle), findsOneWidget);

    app.backend.only(
      'POST',
      '/auth/token/code',
      FakeReply(422, <String, Object?>{
        'code': 'LOGIN_CODE_REJECTED',
        'context': <String, Object?>{'reason': 'expired'},
      }),
    );
    await tester.enterText(field(en.signInCodeLabel), '111111');
    await settle(tester);
    expect(text(en.signInCodeTitle), findsNothing);
    expect(text(en.signInCodeExpired), findsOneWidget);
    expect(field(en.signInPasswordLabel), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('a locked account says so on the password step', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend
      ..on('POST', '/auth/token', FakeReply(202, Payloads.codeChallenge()))
      ..on(
        'POST',
        '/auth/token/code',
        FakeReply(422, <String, Object?>{
          'code': 'LOGIN_CODE_REJECTED',
          'context': <String, Object?>{'reason': 'locked'},
        }),
      );
    await pumpWaiterApp(tester, app);
    await password(tester);
    await tester.enterText(field(en.signInCodeLabel), '000000');
    await settle(tester);
    expect(text(en.signInCodeLocked), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('"Send a new code" and "Back"', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false);
    app.backend
      ..on('POST', '/auth/token', FakeReply(202, Payloads.codeChallenge()))
      ..on(
        'POST',
        '/auth/token/code/resend',
        FakeReply(422, <String, Object?>{
          'code': 'LOGIN_CODE_REJECTED',
          'context': <String, Object?>{'reason': 'wait'},
        }),
      );
    await pumpWaiterApp(tester, app);
    await password(tester);

    await tester.tap(text(en.signInCodeResend));
    await settle(tester);
    expect(text(en.signInCodeWait), findsOneWidget);

    app.backend.only('POST', '/auth/token/code/resend', FakeReply(200, <String, Object?>{'message': 'sent'}));
    await tester.tap(text(en.signInCodeResend));
    await settle(tester);
    expect(text(en.signInCodeSent), findsOneWidget);
    expect(app.backend.to('POST', '/auth/token/code/resend').last.body!['login'], 'login-1');

    await tester.tap(text(en.commonBack));
    await settle(tester);
    expect(text(en.signInCodeTitle), findsNothing);
    expect(field(en.signInPasswordLabel), findsOneWidget);
    expect(app.session.pendingCode, isNull);
    await finishApp(tester, app);
  });

  testWidgets('after an app update the stored sign-in ends and S02 says why', (WidgetTester tester) async {
    final TestApp app = await TestApp.create();
    app.secrets.values['token_version'] = '0.9.0';
    await pumpWaiterApp(tester, app);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(text(en.signInAppUpdated), findsOneWidget);
    expect(app.secrets.values['token'], isNull);
    await finishApp(tester, app);
  });

  testWidgets('the server refusing an older app version signs out with the same notice', (WidgetTester tester) async {
    final TestApp app = await TestApp.create();
    app.backend.on('GET', '/auth/me', FakeReply(401, Payloads.error('APP_UPDATED')));
    await pumpWaiterApp(tester, app);
    await settle(tester, 20);

    expect(find.byType(SignInScreen), findsOneWidget);
    expect(text(en.signInAppUpdated), findsOneWidget);
    await finishApp(tester, app);
  });
}
