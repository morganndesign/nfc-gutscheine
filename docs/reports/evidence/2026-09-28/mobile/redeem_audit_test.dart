// AUDIT reproductions (not part of the product test suite).
// M1, M2, M6, M7, M8, M12 — redeem loop, driven through the app's own
// TestApp harness (real controllers, scripted HTTP backend, fake NFC).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/format/amount_entry.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/state/redeem_attempts.dart';
import 'package:giftcard_waiter/core/state/session_state.dart';

import '../support/app_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String redeemPath = '/cards/${Payloads.cardId}/redeem';
  late TestApp app;

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> started(WidgetTester tester, {bool biometrics = false}) async {
    app = await TestApp.create(biometrics: biometrics);
    unawaited(app.session.start());
    await settle(tester);
    await settle(tester);
  }

  Future<void> tapCard(WidgetTester tester, {String uid = '04:A2:3F:1B:6C:80:12'}) async {
    app.nfc.emit(NfcTagRead(uid: uid, url: Payloads.cardUrl()));
    await settle(tester);
    await settle(tester);
  }

  void typeAmount(int cents) {
    for (final String d in cents.toString().split('')) {
      app.loop.key(int.parse(d));
    }
  }

  ChargeState charge() => app.loop.state as ChargeState;
  List<String?> keys() =>
      app.backend.to('POST', redeemPath).map((RecordedRequest r) => r.header('Idempotency-Key')).toList();

  Future<void> finish(WidgetTester tester) async {
    app.dispose();
    await tester.pump(const Duration(minutes: 1));
  }

  // ---------------------------------------------------------------- M1
  for (final (String code, int status, Map<String, Object?> ctx) in <(String, int, Map<String, Object?>)>[
    ('CARD_NOT_REDEEMABLE', 422, <String, Object?>{'status': 'redeemed'}),
    ('INSUFFICIENT_BALANCE', 422, <String, Object?>{'balance': 0, 'requested': 5000}),
    ('IDEMPOTENCY_CONFLICT', 409, <String, Object?>{}),
  ]) {
    testWidgets('M1: first attempt unanswered 8 s, retry (same key) gets $status $code', (WidgetTester tester) async {
      await started(tester);
      app.backend
        ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
        ..on('POST', redeemPath, FakeReply.hang(const Duration(seconds: 30)))
        ..on('POST', redeemPath, FakeReply(status, Payloads.error(code, ctx)))
        ..on('POST', redeemPath, FakeReply(201, Payloads.redeemed(amount: 5000, balanceAfter: 0)));
      await tapCard(tester);
      typeAmount(5000);
      unawaited(app.loop.redeem());
      await settle(tester);
      expect(charge().phase, RedeemPhase.submitting);
      await tester.pump(const Duration(seconds: 8));
      await settle(tester);

      final List<String?> k = keys();
      // ignore: avoid_print
      print('AUDIT M1[$code] attempts=${k.length} sameKey=${k.toSet().length == 1} '
          'phase=${charge().phase} notice=${charge().notice.runtimeType} '
          'card.status=${charge().card.status} card.balance=${charge().card.balance}');
      expect(k.length, 2);
      expect(k.toSet().length, 1, reason: 'retry reused the key');
      expect(charge().phase, RedeemPhase.entering, reason: 'treated as definitive, not uncertain');
      expect(charge().supportCode, isNull);
      if (code == 'CARD_NOT_REDEEMABLE') expect(charge().notice, isA<NothingBookedNotice>());
      if (code == 'INSUFFICIENT_BALANCE') expect(charge().notice, isA<BalanceChangedNotice>());
      if (code == 'IDEMPOTENCY_CONFLICT') expect(charge().notice, isA<TapAgainNotice>());

      if (code == 'IDEMPOTENCY_CONFLICT') {
        // "Tap again" → the key was discarded, the next tap sends a NEW key.
        unawaited(app.loop.redeem());
        await settle(tester);
        final List<String?> k2 = keys();
        // ignore: avoid_print
        print('AUDIT M1[$code] after tap-again: attempts=${k2.length} key3==key1? ${k2[2] == k2[0]} '
            'state=${app.loop.state.runtimeType}');
        expect(k2[2], isNot(k2[0]), reason: 'second booking possible with a fresh key');
      }
      await finish(tester);
    });
  }

  // ---------------------------------------------------------------- M2
  testWidgets('M2: uncertain → Cancel → edit amount → new key, second redemption without re-scan', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
      ..on('POST', redeemPath, FakeReply(503, Payloads.error('SERVER')))
      ..on('POST', redeemPath, FakeReply(503, Payloads.error('SERVER')))
      ..on('POST', redeemPath, FakeReply(503, Payloads.error('SERVER')))
      ..on('POST', redeemPath, FakeReply(503, Payloads.error('SERVER')))
      ..on('POST', redeemPath, FakeReply(201, Payloads.redeemed(amount: 1500, balanceAfter: 2000)));
    await tapCard(tester);
    typeAmount(1500);
    unawaited(app.loop.redeem());
    await tester.pump(const Duration(seconds: 21));
    await settle(tester);
    expect(charge().phase, RedeemPhase.uncertainFinal);
    final String? firstKey = keys().first;

    app.loop.cancelUncertain();
    expect(charge().phase, RedeemPhase.entering);
    // Edit and restore the SAME amount: 1500 → 150 → 1500.
    app.loop.backspace();
    app.loop.key(0);
    expect(charge().amount, 1500);
    unawaited(app.loop.redeem());
    await settle(tester);
    final String? secondKey = keys().last;
    // ignore: avoid_print
    print('AUDIT M2 first=$firstKey second=$secondKey same=${firstKey == secondKey} '
        'scans=${app.backend.to('POST', '/scan').length} state=${app.loop.state.runtimeType}');
    expect(secondKey, isNot(firstKey), reason: 'same card, same amount, new key after an edit');
    expect(app.backend.to('POST', '/scan'), hasLength(1), reason: 'no re-scan was required');
    expect(app.loop.state, isA<SuccessState>());
    await finish(tester);
  });

  // ---------------------------------------------------------------- M6
  testWidgets('M6: uncertain redeem, background > 15 min → attempt discarded, redo gets a new key', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
      ..on('GET', '/auth/me', FakeReply(200, <String, Object?>{'data': Payloads.user()}))
      ..only('POST', redeemPath, FakeReply(503, Payloads.error('SERVER')));
    await tapCard(tester);
    typeAmount(1500);
    unawaited(app.loop.redeem());
    await tester.pump(const Duration(seconds: 21));
    await settle(tester);
    expect(charge().phase, RedeemPhase.uncertainFinal);
    final String? firstKey = keys().first;

    app.session.onBackground();
    await tester.pump(const Duration(minutes: 16));
    unawaited(app.session.onForeground());
    await settle(tester);
    // ignore: avoid_print
    print('AUDIT M6 after 16 min background: state=${app.loop.state.runtimeType} phase=${app.session.phase}');
    expect(app.loop.state, isA<ReadyState>(), reason: 'uncertain S07 silently dropped');

    await tapCard(tester, uid: '04:00:00:00:00:00:02');
    typeAmount(1500);
    unawaited(app.loop.redeem());
    await settle(tester);
    // ignore: avoid_print
    print('AUDIT M6 redo key=${keys().last} first=$firstKey same=${keys().last == firstKey}');
    expect(keys().last, isNot(firstKey));
    await tester.pump(const Duration(seconds: 21));
    await finish(tester);
  });

  test('M6b: RedeemAttempts is memory-only — a new instance (process restart) issues a new key', () {
    final RedeemAttempts before = RedeemAttempts();
    final String k1 = before.keyFor('card', 1500);
    final RedeemAttempts afterKill = RedeemAttempts();
    // ignore: avoid_print
    print('AUDIT M6b hasPending after restart=${afterKill.hasPending('card', 1500)}');
    expect(afterKill.hasPending('card', 1500), isFalse);
    expect(afterKill.keyFor('card', 1500), isNot(k1));
  });

  // ---------------------------------------------------------------- M7
  testWidgets('M7: NFC tag event delivered while launching (cold start) is dropped', (WidgetTester tester) async {
    app = await TestApp.create();
    app.backend.on('POST', '/scan', FakeReply(200, Payloads.scan()));
    expect(app.session.phase, AccessPhase.launching);
    // ignore: avoid_print
    print('AUDIT M7 wantsReaderMode while launching=${app.loop.wantsReaderMode}');
    app.nfc.emit(NfcTagRead(uid: '04:A2:3F:1B:6C:80:12', url: Payloads.cardUrl()));
    await settle(tester);
    unawaited(app.session.start());
    await settle(tester);
    await settle(tester);
    // ignore: avoid_print
    print('AUDIT M7 after start: phase=${app.session.phase} state=${app.loop.state.runtimeType} '
        'scans=${app.backend.to('POST', '/scan').length}');
    expect(app.session.phase, AccessPhase.active);
    expect(app.backend.to('POST', '/scan'), isEmpty, reason: 'the launching tap was lost');
    expect(app.loop.state, isA<ReadyState>());
    await finish(tester);
  });

  testWidgets('M7b: same tap with biometrics enabled (phase locked) is dropped too; a link is kept', (WidgetTester tester) async {
    await started(tester, biometrics: true);
    expect(app.session.phase, AccessPhase.locked);
    app.nfc.emit(NfcTagRead(uid: '04:A2:3F:1B:6C:80:12', url: Payloads.cardUrl()));
    await settle(tester);
    app.loop.openLink(Payloads.cardUrl());
    // ignore: avoid_print
    print('AUDIT M7b locked: scans=${app.backend.to('POST', '/scan').length} '
        'pendingLinkKept=${app.session.hasPendingLink}');
    expect(app.backend.to('POST', '/scan'), isEmpty);
    expect(app.session.hasPendingLink, isTrue, reason: 'links are kept, NFC tags are not');
    await finish(tester);
  });

  // ---------------------------------------------------------------- M8
  test('M8a: AmountEntry.fromCents throws above 9 999 999', () {
    Object? error;
    try {
      AmountEntry.fromCents(10000000);
    } on Object catch (e) {
      error = e;
    }
    // ignore: avoid_print
    print('AUDIT M8a fromCents(10000000) → $error');
    expect(error, isA<RangeError>());
  });

  for (final bool partial in <bool>[false, true]) {
    testWidgets('M8b: lookup of a €100 000 card, partial=$partial', (WidgetTester tester) async {
      final List<Object> errors = <Object>[];
      // Controllers are built inside a guarded zone so the uncaught async
      // error from the unawaited _lookup() is captured instead of failing the test.
      await runZonedGuarded(() async {
        app = await TestApp.create();
        unawaited(app.session.start());
      }, (Object e, StackTrace s) => errors.add(e));
      await settle(tester);
      await settle(tester);
      app.backend.on('POST', '/scan', FakeReply(200, Payloads.scan(balance: 10000000, partial: partial)));
      await tapCard(tester);
      final Object? uncaught = errors.isEmpty ? null : errors.first;
      await tester.pump(const Duration(seconds: 5));
      // ignore: avoid_print
      print('AUDIT M8b partial=$partial state=${app.loop.state.runtimeType} '
          '${app.loop.state is LookingUpState ? 'slow=${(app.loop.state as LookingUpState).slow}' : ''} '
          'uncaught=${uncaught.runtimeType} wantsReaderMode=${app.loop.wantsReaderMode}');
      if (!partial) {
        // ignore: avoid_print
        print('AUDIT M8b uncaught error: $uncaught');
        expect(uncaught, isA<RangeError>());
        expect(app.loop.state, isA<LookingUpState>(), reason: 'spinner forever');
        // A new tap is ignored while LookingUp; only Back escapes.
        await tapCard(tester, uid: '04:00:00:00:00:00:09');
        expect(app.backend.to('POST', '/scan'), hasLength(1));
        expect(app.loop.back(), isTrue);
        // ignore: avoid_print
        print('AUDIT M8b after back(): ${app.loop.state.runtimeType}');
      } else {
        expect(uncaught, isNull);
        expect(app.loop.state, isA<ChargeState>());
      }
      await finish(tester);
    });
  }

  // ---------------------------------------------------------------- M12
  testWidgets('M12a: double tap on Redeem sends exactly one request', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
      ..on('POST', redeemPath, FakeReply(201, Payloads.redeemed(amount: 1000, balanceAfter: 4000), const Duration(milliseconds: 300)));
    await tapCard(tester);
    typeAmount(1000);
    unawaited(app.loop.redeem());
    unawaited(app.loop.redeem());
    await settle(tester);
    unawaited(app.loop.redeem());
    await tester.pump(const Duration(seconds: 1));
    // ignore: avoid_print
    print('AUDIT M12a redeem requests=${keys().length} state=${app.loop.state.runtimeType}');
    expect(keys(), hasLength(1));
    await finish(tester);
  });

  testWidgets('M12b: uncertain retries + Try again + reconnect all reuse one key', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
      ..only('POST', redeemPath, FakeReply.transport());
    await tapCard(tester);
    typeAmount(1000);
    unawaited(app.loop.redeem());
    await tester.pump(const Duration(seconds: 21));
    await settle(tester);
    expect(charge().phase, RedeemPhase.uncertainFinal);
    unawaited(app.loop.tryAgain());
    await tester.pump(const Duration(seconds: 21));
    await settle(tester);
    app.loop.cancelUncertain();
    unawaited(app.loop.redeem()); // same amount, no edit
    await tester.pump(const Duration(seconds: 21));
    final List<String?> k = keys();
    // ignore: avoid_print
    print('AUDIT M12b attempts=${k.length} distinctKeys=${k.toSet().length}');
    expect(k.toSet(), hasLength(1));
    await finish(tester);
  });

  testWidgets('M12c: 5xx on the slow retry stays uncertain (not definitive)', (WidgetTester tester) async {
    await started(tester);
    app.backend
      ..on('POST', '/scan', FakeReply(200, Payloads.scan()))
      ..on('POST', redeemPath, FakeReply.hang(const Duration(seconds: 30)))
      ..on('POST', redeemPath, FakeReply(500, Payloads.error('SERVER')))
      ..on('POST', redeemPath, FakeReply(201, Payloads.redeemed(amount: 1000, balanceAfter: 4000, replayed: true)));
    await tapCard(tester);
    typeAmount(1000);
    unawaited(app.loop.redeem());
    await tester.pump(const Duration(seconds: 8));
    await settle(tester);
    // ignore: avoid_print
    print('AUDIT M12c after 8s+500: phase=${charge().phase}');
    expect(charge().phase, RedeemPhase.uncertainAuto);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(app.loop.state, isA<SuccessState>());
    expect(keys().toSet(), hasLength(1));
    await finish(tester);
  });
}
