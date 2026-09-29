import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';
import 'package:giftcard_waiter/screens/s02_sign_in.dart';
import 'package:giftcard_waiter/screens/s05_ready.dart';
import 'package:giftcard_waiter/screens/s07_charge.dart';
import 'package:giftcard_waiter/screens/s09_success.dart';
import 'package:giftcard_waiter/screens/s12_qr_scan.dart';
import 'package:giftcard_waiter/screens/s17_intro.dart';

import '../screens/charge/charge_harness.dart' show redeemPath, rich, typeDigits;
import '../screens/scan/scan_harness.dart' show mockDeniedCamera;
import '../support/app_harness.dart';
import '../support/screen_harness.dart';

Finder _primary(String label) => find.ancestor(of: rich(label), matching: find.byType(PrimaryButton));

/// End-to-end journey of a waiter's first shift through the real app
/// (navigator, controllers, screens, components) with a scripted backend and
/// the camera answered by the platform as "denied" (the QR itself is fed to
/// the loop, as S12 does on a detection): sign in → intro → S05 → "Scan
/// voucher" → S12 → S07 → type amount → Redeem → S09 → S05 → Recent → sign out.
void main() {
  testWidgets('first shift: sign in, redeem € 24,90, see it in Recent, sign out', (WidgetTester tester) async {
    mockDeniedCamera();
    final TestApp app = await TestApp.create(signedIn: false, introDone: false, biometricsOffered: true);
    app.backend
      ..on('POST', '/auth/token', FakeReply(201, Payloads.token()))
      ..on('GET', '/auth/me', FakeReply(200, <String, Object?>{'data': Payloads.user()}))
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
      ..on('POST', redeemPath, FakeReply(201, Payloads.redeemed(amount: 2490, balanceAfter: 2510)))
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

    // S05 → "Scan voucher" → S12 (camera denied by the platform)
    expect(find.byType(ReadyScreen), findsOneWidget);
    expect(find.byType(SecondaryButton), findsNothing, reason: 'a waiter cannot sell');
    await tester.tap(_primary('Scan voucher'));
    await settle(tester, 10);
    expect(app.loop.state, isA<QrScanState>());
    expect(find.byType(QrScanScreen), findsOneWidget);
    expect(rich('Camera access is off'), findsOneWidget);

    // A voucher QR → POST /presentments → S07
    expect(app.loop.qrDetected(Payloads.qr), isTrue);
    await settle(tester, 12);
    expect(find.byType(ChargeScreen), findsOneWidget);
    expect(app.backend.to('POST', '/presentments').single.body, <String, Object?>{
      'purpose': 'spend',
      'method': 'printable_qr',
      'credential': Payloads.qr,
    });

    await typeDigits(tester, '2490');
    expect((app.loop.state as ChargeState).amount, 2490);

    await tester.tap(_primary('Redeem'));
    await settle(tester, 12);

    // S09 with server values
    expect(find.byType(SuccessScreen), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    final RecordedRequest redeem = app.backend.to('POST', redeemPath).single;
    expect(redeem.body, <String, Object?>{'amount': 2490, 'presentment_id': Payloads.presentmentId});
    expect(redeem.header('Idempotency-Key'), isNotNull);
    expect(rich('Remaining balance'), findsOneWidget);
    expect(rich('25,10'), findsOneWidget);
    expect(rich('Show guest'), findsOneWidget);
    expect(_primary('Scan next voucher'), findsOneWidget);
    expect(app.services.recent.entries.single.amount, 2490);
    expect(app.pending.entries, isEmpty);
    expect(app.sounds.where((String s) => s == 'gcw_success'), hasLength(1));

    // Automatic return to S05
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    expect(find.byType(ReadyScreen), findsOneWidget);

    // Every request of the loop, in order.
    expect(
      app.backend.requests
          .where((RecordedRequest r) => r.path == '/presentments' || r.path.startsWith('/vouchers/'))
          .map((RecordedRequest r) => '${r.method} ${r.path}'),
      <String>['POST /presentments', 'POST $redeemPath'],
    );

    // Recent shows the redemption.
    await tester.tap(find.bySemanticsLabel('Recent'));
    await settle(tester);
    expect(find.textContaining('24,90', findRichText: true), findsWidgets);
    await tester.tapAt(const Offset(200, 60));
    await settle(tester);

    // Sign out clears token and Recent
    unawaited(app.session.signOut());
    await settle(tester);
    expect(app.session.phase, AccessPhase.signedOut);
    expect(app.secrets.values.containsKey('token'), isFalse);
    expect(app.services.recent.entries, isEmpty);
    expect(find.byType(SignInScreen), findsOneWidget);

    await finishApp(tester, app);
  });

  testWidgets('two vouchers in a row: S09 "Scan next voucher" opens S12 straight away', (WidgetTester tester) async {
    mockDeniedCamera();
    final TestApp app = await TestApp.create();
    const String secondId = 'aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee';
    app.backend
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment()))
      ..on('POST', '/presentments', FakeReply(201, Payloads.presentment(id: secondId, balance: 1000)))
      ..on('POST', redeemPath, FakeReply(201, Payloads.redeemed(amount: 2490, balanceAfter: 2510)))
      ..on('POST', redeemPath, FakeReply(201, Payloads.redeemed(amount: 1000, balanceAfter: 0)));
    await pumpWaiterApp(tester, app);

    // First voucher.
    await tester.tap(_primary('Scan voucher'));
    await settle(tester, 10);
    app.loop.qrDetected(Payloads.qr);
    await settle(tester, 12);
    await typeDigits(tester, '2490');
    await tester.tap(_primary('Redeem'));
    await settle(tester, 12);
    expect(find.byType(SuccessScreen), findsOneWidget);

    // "Scan next voucher" → S12 without passing S05.
    await tester.tap(_primary('Scan next voucher'));
    await settle(tester, 10);
    expect(app.loop.state, isA<QrScanState>());
    expect(find.byType(QrScanScreen), findsOneWidget);

    // Second voucher, redeemed in full.
    app.loop.qrDetected(Payloads.qr);
    await settle(tester, 12);
    expect(find.byType(ChargeScreen), findsOneWidget);
    await typeDigits(tester, '1000');
    await tester.tap(_primary('Redeem'));
    await settle(tester, 12);
    expect(find.byType(SuccessScreen), findsOneWidget);

    final List<RecordedRequest> redemptions = app.backend.to('POST', redeemPath);
    expect(redemptions.map((RecordedRequest r) => r.body), <Map<String, Object?>>[
      <String, Object?>{'amount': 2490, 'presentment_id': Payloads.presentmentId},
      <String, Object?>{'amount': 1000, 'presentment_id': secondId},
    ]);
    expect(
      redemptions.map((RecordedRequest r) => r.header('Idempotency-Key')).toSet(),
      hasLength(2),
      reason: 'a new attempt gets a new key',
    );
    expect(app.backend.to('POST', '/presentments'), hasLength(2));
    expect(app.services.recent.entries, hasLength(2));

    // ✕-free return: the countdown brings S05 back.
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(find.byType(ReadyScreen), findsOneWidget);
    await finishApp(tester, app);
  });
}
