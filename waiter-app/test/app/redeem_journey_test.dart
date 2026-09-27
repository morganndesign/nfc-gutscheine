import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/screens/s02_sign_in.dart';
import 'package:giftcard_waiter/screens/s05_ready.dart';
import 'package:giftcard_waiter/screens/s07_charge.dart';
import 'package:giftcard_waiter/screens/s09_success.dart';
import 'package:giftcard_waiter/screens/s17_intro.dart';

import '../support/app_harness.dart';
import '../support/screen_harness.dart';

/// End-to-end journey of a waiter's first shift through the real app
/// (navigator, controllers, screens, components) with scripted backend and
/// NFC: sign in → skip biometrics → intro → tap card → type amount → redeem →
/// success → Recent → sign out (02 §5.2, §5.5).
void main() {
  testWidgets('first shift: sign in, redeem € 24,90, see it in Recent, sign out', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(signedIn: false, introDone: false, biometricsOffered: true);
    app.backend
      ..on('POST', '/auth/token', FakeReply(201, Payloads.token()))
      ..on('GET', '/auth/me', FakeReply(200, <String, Object?>{'data': Payloads.user()}))
      ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
      ..on('POST', '/cards/${Payloads.cardId}/redeem', FakeReply(201, Payloads.redeemed(amount: 2490, balanceAfter: 2510)))
      ..on('POST', '/auth/logout', FakeReply(200, <String, Object?>{'message': 'Logged out.'}));
    await pumpWaiterApp(tester, app);

    // S02
    expect(find.byType(SignInScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'anna@example.at');
    await tester.enterText(find.byType(TextField).at(1), 'Password123!');
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton).first);
    await settle(tester);
    final RecordedRequest signIn = app.backend.to('POST', '/auth/token').single;
    expect(signIn.body!['device_id'], '00000000-0000-4000-8000-000000000001');
    expect(signIn.body!['platform'], 'android');

    // S17 (biometrics already offered on this install)
    expect(find.byType(IntroScreen), findsOneWidget);
    for (int i = 0; i < 3; i++) {
      await tester.tap(find.byType(PrimaryButton));
      await settle(tester);
    }

    // S05 → tap → S07
    expect(find.byType(ReadyScreen), findsOneWidget);
    expect(app.nfc.calls.last, 'readerMode:true');
    app.nfc.emit(NfcTagRead(uid: '04:A2:3F:1B:6C:80:12', url: Payloads.cardUrl()));
    await settle(tester, 12);
    expect(find.byType(ChargeScreen), findsOneWidget);

    for (final String digit in <String>['2', '4', '9', '0']) {
      await tester.tap(find.bySemanticsLabel(digit).last);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect((app.loop.state as ChargeState).amount, 2490);

    await tester.tap(find.byType(PrimaryButton).last);
    await settle(tester, 12);

    // S09 with server values, then automatic return
    expect(find.byType(SuccessScreen), findsOneWidget);
    expect(app.backend.to('POST', '/cards/${Payloads.cardId}/redeem').single.body, <String, Object?>{'amount': 2490});
    expect(app.services.recent.entries.single.amount, 2490);
    expect(app.sounds.where((String s) => s == 'gcw_success'), hasLength(1));
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    expect(find.byType(ReadyScreen), findsOneWidget);

    // Sign out clears token and Recent
    unawaited(app.session.signOut());
    await settle(tester);
    expect(app.session.phase, AccessPhase.signedOut);
    expect(app.secrets.values.containsKey('token'), isFalse);
    expect(app.services.recent.entries, isEmpty);
    expect(find.byType(SignInScreen), findsOneWidget);

    await finishApp(tester, app);
  });
}
