import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';

import '../../support/app_harness.dart';

/// The redeem loop against 02 §4.5 and the redeem state table of 09 §4.4
/// (invariants I1–I6), with a scripted backend.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String redeemPath = '/cards/${Payloads.cardId}/redeem';

  late TestApp app;

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> started(WidgetTester tester, {bool isIos = false}) async {
    app = await TestApp.create(isIos: isIos);
    unawaited(app.session.start());
    await settle(tester);
  }

  Future<void> tapCard(WidgetTester tester, {String uid = '04:A2:3F:1B:6C:80:12', bool sun = false}) async {
    app.nfc.emit(NfcTagRead(uid: uid, url: Payloads.cardUrl(sun: sun)));
    await settle(tester);
  }

  void typeAmount(int cents) {
    for (final String d in cents.toString().split('')) {
      app.loop.key(int.parse(d));
    }
  }

  ChargeState charge() => app.loop.state as ChargeState;

  testWidgets('Android tap → lookup → charge → redeem → success → auto-return (happy path)', (WidgetTester tester) async {
    {
      await started(tester);
      await settle(tester);
      expect(app.session.phase, AccessPhase.active);
      app.backend
        ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
        ..on('POST', redeemPath, FakeReply(201, Payloads.redeemed(amount: 2490, balanceAfter: 2510)));

      await tapCard(tester);
      await settle(tester);
      expect(app.loop.state, isA<ChargeState>());
      final Map<String, Object?> scan = app.backend.to('POST', '/scan').single.body!;
      expect(scan['method'], 'nfc');
      expect(scan['nfc_uid'], '04:A2:3F:1B:6C:80:12');

      typeAmount(2490);
      expect(charge().amount, 2490);
      unawaited(app.loop.redeem());
      await settle(tester);

      expect(app.loop.state, isA<SuccessState>());
      final SuccessState success = app.loop.state as SuccessState;
      expect(success.entry.amount, 2490);
      expect(success.entry.balanceAfter, 2510, reason: 'I5: from the server');
      expect(app.services.recent.entries.single.last4, '6488');
      expect(app.sounds, containsAllInOrder(<String>['gcw_card_detected', 'gcw_success']));

      final RecordedRequest redeem = app.backend.to('POST', redeemPath).single;
      expect(redeem.body, <String, Object?>{'amount': 2490});
      expect(redeem.header('Idempotency-Key'), isNotNull);
      expect(redeem.header('X-Device-Id'), '00000000-0000-4000-8000-000000000001');
      expect(redeem.header('Authorization'), 'Bearer gcp_test');

      await tester.pump(const Duration(seconds: 4));
      expect(app.loop.state, isA<SuccessState>(), reason: 'AC-S09-3: 4.52 s after the response');
      await tester.pump(const Duration(milliseconds: 520));
      expect(app.loop.state, isA<ReadyState>());
      app.dispose();
      await tester.pump();
    }
  });

  testWidgets('I1/K4: slow first attempt and uncertain retries reuse one key with new request ids', (WidgetTester tester) async {
    {
      await started(tester);
      await settle(tester);
      app.backend
        ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
        ..on('POST', redeemPath, FakeReply.hang(const Duration(seconds: 30)))
        ..on('POST', redeemPath, FakeReply.transport())
        ..on('POST', redeemPath, FakeReply(200, Payloads.redeemed(amount: 1000, balanceAfter: 4000, replayed: true)));
      await tapCard(tester);
      await settle(tester);
      typeAmount(1000);

      final Future<void> done = app.loop.redeem();
      await settle(tester);
      expect(charge().phase, RedeemPhase.submitting);
      expect(charge().isLocked, isTrue, reason: 'I4: no navigation while submitting');
      expect(app.loop.back(), isTrue);
      expect(app.loop.state, isA<ChargeState>());

      await tester.pump(const Duration(seconds: 8));
      await settle(tester);
      // Second attempt fails at once (transport) → uncertain, retry after 1 s.
      expect(charge().phase, RedeemPhase.uncertainAuto);
      await tester.pump(const Duration(seconds: 1));
      await settle(tester);
      unawaited(done);

      expect(app.loop.state, isA<SuccessState>(), reason: 'I3: replayed renders like 201');
      final List<RecordedRequest> attempts = app.backend.to('POST', redeemPath);
      expect(attempts.length, 3);
      expect(attempts.map((RecordedRequest r) => r.header('Idempotency-Key')).toSet().length, 1);
      expect(attempts.map((RecordedRequest r) => r.header('X-Request-Id')).toSet().length, 3);
      app.dispose();
      await tester.pump();
    }
  });

  testWidgets('Uncertain final after 20 s; Cancel keeps the attempt, a new amount gets a new key', (WidgetTester tester) async {
    {
      await started(tester);
      await settle(tester);
      app.backend
        ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
        ..on('POST', redeemPath, FakeReply(503, Payloads.error('SERVER')));
      await tapCard(tester);
      await settle(tester);
      typeAmount(1500);
      unawaited(app.loop.redeem());
      await tester.pump(const Duration(seconds: 21));
      await settle(tester);
      expect(charge().phase, RedeemPhase.uncertainFinal);
      expect(charge().supportCode, hasLength(6));

      app.loop.cancelUncertain();
      expect(charge().phase, RedeemPhase.entering);
      expect(charge().notice, isA<UncertainCancelledNotice>());

      final String? firstKey = app.backend.to('POST', redeemPath).first.header('Idempotency-Key');
      unawaited(app.loop.redeem());
      await settle(tester);
      expect(app.backend.to('POST', redeemPath).last.header('Idempotency-Key'), firstKey, reason: 'K6: same card + amount');
      await tester.pump(const Duration(seconds: 21));
      app.loop.cancelUncertain();

      app.loop.backspace();
      app.loop.key(1);
      unawaited(app.loop.redeem());
      await settle(tester);
      expect(app.backend.to('POST', redeemPath).last.header('Idempotency-Key'), isNot(firstKey), reason: 'K5: amount changed');
      await tester.pump(const Duration(seconds: 21));
      app.dispose();
      await tester.pump();
    }
  });

  testWidgets('I2: no redeem request while the OS reports no network', (WidgetTester tester) async {
    {
      await started(tester);
      await settle(tester);
      app.backend.on('POST', '/scan', FakeReply(200, Payloads.scan()));
      await tapCard(tester);
      await settle(tester);
      typeAmount(500);
      app.connectivity.setOnline(false);
      unawaited(app.loop.redeem());
      await settle(tester);
      expect(app.backend.to('POST', redeemPath), isEmpty);
      expect(charge().phase, RedeemPhase.entering);
      app.dispose();
      await tester.pump();
    }
  });

  testWidgets('Definitive 4xx: insufficient balance updates the card from context and closes the key', (WidgetTester tester) async {
    {
      await started(tester);
      await settle(tester);
      app.backend
        ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
        ..on('POST', redeemPath, FakeReply(422, Payloads.error('INSUFFICIENT_BALANCE', <String, Object?>{'balance': 1200, 'requested': 2000})));
      await tapCard(tester);
      await settle(tester);
      typeAmount(2000);
      unawaited(app.loop.redeem());
      await settle(tester);
      expect(charge().card.balance, 1200);
      expect(charge().notice, isA<BalanceChangedNotice>());
      expect(app.backend.to('POST', '/scan'), hasLength(1), reason: '03b §1.2: never re-scans');
      expect(app.sounds.last, 'gcw_error');
      app.dispose();
      await tester.pump();
    }
  });

  testWidgets('401 during redeem opens the session sheet and keeps the attempt (K6)', (WidgetTester tester) async {
    {
      await started(tester);
      await settle(tester);
      app.backend
        ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
        ..on('POST', redeemPath, FakeReply(401, Payloads.error('UNAUTHENTICATED')))
        ..on('POST', redeemPath, FakeReply(201, Payloads.redeemed(amount: 700, balanceAfter: 4300)))
        ..on('POST', '/auth/token', FakeReply(201, Payloads.token()));
      await tapCard(tester);
      await settle(tester);
      typeAmount(700);
      unawaited(app.loop.redeem());
      await settle(tester);
      expect(app.session.expired, SessionContext.redeem);
      expect(charge().amount, 700);

      unawaited(app.session.reauthenticate('Password123!'));
      await settle(tester);
      expect(app.session.expired, isNull);
      unawaited(app.loop.redeem());
      await settle(tester);
      final List<RecordedRequest> attempts = app.backend.to('POST', redeemPath);
      expect(attempts[0].header('Idempotency-Key'), attempts[1].header('Idempotency-Key'));
      expect(app.loop.state, isA<SuccessState>());
      app.dispose();
      await tester.pump();
    }
  });

  testWidgets('Device revoked blocks the app and clears the token', (WidgetTester tester) async {
    {
      await started(tester);
      await settle(tester);
      app.backend.on('POST', '/scan', FakeReply(403, Payloads.error('DEVICE_REVOKED')));
      await tapCard(tester);
      await settle(tester);
      expect(app.session.phase, AccessPhase.blocked);
      expect(app.session.blocked, BlockedKind.deviceRevoked);
      expect(app.secrets.values.containsKey('token'), isFalse);
      expect(app.loop.state, isA<ReadyState>());
      app.dispose();
      await tester.pump();
    }
  });

  testWidgets('Lookup problems: not found (manual keeps digits), SUN card never retried, throttled countdown', (WidgetTester tester) async {
    {
      await started(tester);
      await settle(tester);
      app.backend
        ..on('POST', '/scan', FakeReply(404, Payloads.error('CARD_NOT_FOUND')))
        ..on('POST', '/scan', FakeReply.transport())
        ..on('POST', '/scan', FakeReply(429, <String, Object?>{'code': 'SCAN_THROTTLED', 'retry_after': 30}));

      app.loop.openManual();
      app.loop.submitManual('5285105870986488');
      await settle(tester);
      final ProblemState notFound = app.loop.state as ProblemState;
      expect(notFound.kind, ProblemKind.notFoundManual);
      expect(notFound.manualDigits, '5285105870986488');
      app.loop.editNumber();
      expect((app.loop.state as ManualEntryState).prefill, '5285105870986488');
      app.loop.back();

      await tapCard(tester, sun: true);
      await settle(tester);
      final ProblemState network = app.loop.state as ProblemState;
      expect(network.kind, ProblemKind.network);
      expect(network.retry, isNull, reason: '03b §1.2: SUN URL is single-use');
      app.loop.back();

      await tester.pump(const Duration(seconds: 3));
      await tapCard(tester, uid: '04:00:00:00:00:00:01');
      await settle(tester);
      final ProblemState throttled = app.loop.state as ProblemState;
      expect(throttled.kind, ProblemKind.throttled);
      expect(app.loop.wantsReaderMode, isFalse, reason: 'L05: reader paused during the countdown');
      await tester.pump(const Duration(seconds: 30));
      expect(app.loop.wantsReaderMode, isTrue);
      app.dispose();
      await tester.pump();
    }
  });

  testWidgets('Android: a second card with an amount typed offers a switch; duplicate reads are ignored', (WidgetTester tester) async {
    {
      await started(tester);
      await settle(tester);
      app.backend.on('POST', '/scan', FakeReply(200, Payloads.scan()));
      await tapCard(tester);
      await settle(tester);
      await tapCard(tester);
      expect(app.backend.to('POST', '/scan'), hasLength(1), reason: 'same UID within 2 s');
      typeAmount(300);
      await tester.pump(const Duration(seconds: 3));
      await tapCard(tester, uid: '04:99:99:99:99:99:99');
      expect(charge().pendingSwitch, isNotNull);
      expect(app.backend.to('POST', '/scan'), hasLength(1));
      app.loop.acceptSwitch();
      await settle(tester);
      expect(app.backend.to('POST', '/scan'), hasLength(2));
      expect(charge().amount, 0);
      app.dispose();
      await tester.pump();
    }
  });

  testWidgets('Card states: blocked card cannot be redeemed and plays the error sound', (WidgetTester tester) async {
    {
      await started(tester);
      await settle(tester);
      app.backend.on('POST', '/scan', FakeReply(200, Payloads.scan(status: 'blocked')));
      await tapCard(tester);
      await settle(tester);
      expect(charge().condition, CardCondition.blocked);
      typeAmount(100);
      expect(charge().amount, 0);
      expect(app.sounds.last, 'gcw_error');
      app.dispose();
      await tester.pump();
    }
  });

  testWidgets('Partial redemption disabled: the amount is the full balance', (WidgetTester tester) async {
    {
      await started(tester);
      await settle(tester);
      app.backend.on('POST', '/scan', FakeReply(200, Payloads.scan(balance: 3150, partial: false)));
      await tapCard(tester);
      await settle(tester);
      expect(charge().fullOnly, isTrue);
      expect(charge().amount, 3150);
      app.loop.key(1);
      expect(charge().amount, 3150);
      app.dispose();
      await tester.pump();
    }
  });

  testWidgets('iPhone: sheet cancel returns silently with the hint; rejected tag keeps the session', (WidgetTester tester) async {
    {
      await started(tester, isIos: true);
      await settle(tester);
      unawaited(app.loop.startScan(testSheetTexts));
      await settle(tester);
      expect(app.loop.state, isA<ScanningState>());
      app.nfc.emit(const NfcTagRead(uid: '04:01', url: 'https://bank.example.com/x'));
      await settle(tester);
      expect(app.nfc.calls, contains('rejectTag'));
      app.nfc.emit(const NfcSessionEnded(NfcSessionEnd.timeout));
      await settle(tester);
      expect((app.loop.state as ReadyState).notice, ReadyNotice.iosTimeout);
      expect(app.sounds, isEmpty, reason: 'E16: silent');
      app.dispose();
      await tester.pump();
    }
  });
}

const IosSheetTexts testSheetTexts = IosSheetTexts(
  alert: 'Hold the card near the top of the iPhone',
  found: 'Card found',
  multiple: 'More than one card detected. Hold only one.',
  readFailed: 'Couldn’t read the card. Hold it still for a second.',
  timeoutSoon: 'No card yet.',
  notCard: 'This is not a gift card',
);

