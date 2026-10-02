import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/api/models.dart';
import 'package:giftcard_waiter/core/platform/nfc_relay.dart';
import 'package:giftcard_waiter/core/station/station_controller.dart';

import '../../support/app_harness.dart';

/// The personalisation station: the phone relays the server's rounds to one blank chip after the other and
/// never interprets a command.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const String begin = '/admin/card-batches/b-1/personalizations';
  late TestApp app;
  late StationController station;

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
  }

  Future<void> started(WidgetTester tester) async {
    final FakeNfcRelay nfc = FakeNfcRelay()..card = null;
    app = await TestApp.create(user: Payloads.stationUser(), nfc: nfc);
    app.backend.on('GET', '/admin/station/batches', FakeReply(200, Payloads.stationBatches()));
    unawaited(app.session.start());
    await settle(tester);
    station = StationController(api: app.services.api, nfc: app.nfc, prompt: () => 'Hold a blank card', pause: Duration.zero);
    unawaited(station.load());
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    station.dispose();
    app.dispose();
    await tester.pump(const Duration(minutes: 2));
  }

  FakeCard chip(Map<String, String> answers) =>
      FakeCard(uidHex: '04112233445566')..script = (String apdu) => answers[apdu];

  testWidgets('a station account is a station, not a till', (WidgetTester tester) async {
    await started(tester);
    final SessionUser user = app.session.user!;
    expect(user.isStation, isTrue);
    expect(user.canUseApp, isTrue);
    expect(user.canRedeem, isFalse);
    expect(station.batches!.single.batchCode, 'B-2026-001');
    expect(station.batches!.single.qaPassed, 2);
    await finish(tester);
  });

  testWidgets('each round is relayed byte for byte until done, then the next card is awaited', (
    WidgetTester tester,
  ) async {
    await started(tester);
    app.nfc.queue.add(
      chip(<String, String>{
        '00A4040007D276000085010100': '9000',
        '9071000002000000': 'A04C124213C186F22399D33AC2A3021591AF',
        '90AF000020AABB00': '0011223344556677889900112233445566778899001122334455667788990011229100',
      }),
    );
    app.backend
      ..on(
        'POST',
        begin,
        FakeReply(200, Payloads.round(id: 'P1', commands: <String>['00A4040007D276000085010100', '9071000002000000'])),
      )
      ..on(
        'POST',
        '/admin/personalizations/P1',
        FakeReply(200, Payloads.round(id: 'P2', stage: 'auth2', commands: <String>['90AF000020AABB00'])),
      )
      ..on('POST', '/admin/personalizations/P2', FakeReply(200, Payloads.round(stage: 'done', state: 'qa_passed')));

    unawaited(station.choose(station.batches!.single));
    await settle(tester);

    expect(app.nfc.sent, <String>['00A4040007D276000085010100', '9071000002000000', '90AF000020AABB00']);
    expect(app.backend.to('POST', begin).single.body, <String, Object?>{'rf_uid': '04112233445566'});
    expect(app.backend.to('POST', '/admin/personalizations/P1').single.body, <String, Object?>{
      'responses': <String>['9000', 'A04C124213C186F22399D33AC2A3021591AF'],
    });
    expect(station.last!.cardNumber, 'B-2026-001-0003');
    expect(station.finished, 1);
    expect(app.nfc.closed.single.failed, isFalse);
    // The next blank: the reader waits again.
    expect(station.phase, StationPhase.waiting);
    expect(app.nfc.prompts, <String>['Hold a blank card', 'Hold a blank card']);

    unawaited(station.finish());
    await settle(tester);
    expect(app.nfc.cancels, 1);
    expect(station.phase, StationPhase.batches);
    expect(station.batch, isNull);
    await finish(tester);
  });

  testWidgets('the relay stops at the first refused command and sends what it has', (WidgetTester tester) async {
    await started(tester);
    app.nfc.queue.add(chip(<String, String>{'AA': '9000', 'BB': '919D', 'CC': '9100'}));
    app.backend
      ..on(
        'POST',
        begin,
        FakeReply(200, Payloads.round(id: 'P1', commands: <String>['AA000000', 'BB000000', 'CC000000'])),
      )
      ..on(
        'POST',
        '/admin/personalizations/P1',
        FakeReply(422, Payloads.error('CARD_PERSONALIZATION_FAILED', <String, Object?>{'reason': 'write:919D'})),
      );
    app.nfc.queue.last.script = (String apdu) =>
        <String, String>{'AA000000': '9000', 'BB000000': '919D', 'CC000000': '9100'}[apdu];

    unawaited(station.choose(station.batches!.single));
    await settle(tester);

    expect(app.nfc.sent, <String>['AA000000', 'BB000000']);
    expect(app.backend.to('POST', '/admin/personalizations/P1').single.body, <String, Object?>{
      'responses': <String>['9000', '919D'],
    });
    expect(station.last!.failure, StationFailure.refused);
    expect(station.finished, 0);
    expect(app.nfc.closed.single.failed, isTrue);
    expect(station.phase, StationPhase.waiting);
    await finish(tester);
  });

  testWidgets('refusals say whether to hold the card again or set it aside', (WidgetTester tester) async {
    await started(tester);
    for (final (String reason, StationFailure failure) in <(String, StationFailure)>[
      ('auth:91AE', StationFailure.unknownChip),
      ('other_batch', StationFailure.rejected),
      ('already_personalized', StationFailure.rejected),
      ('expired', StationFailure.refused),
    ]) {
      app.backend.only(
        'POST',
        begin,
        FakeReply(422, Payloads.error('CARD_PERSONALIZATION_FAILED', <String, Object?>{'reason': reason})),
      );
      app.nfc.queue.add(chip(const <String, String>{}));
      unawaited(station.choose(station.batches!.single));
      await settle(tester);
      expect(station.last!.failure, failure, reason: reason);
      unawaited(station.finish());
      await settle(tester);
    }

    // The card left the phone in the middle of a round.
    app.backend.only('POST', begin, FakeReply(200, Payloads.round(id: 'P1', commands: <String>['DD000000'])));
    app.nfc.queue.add(chip(const <String, String>{})..loseOn = 'DD');
    unawaited(station.choose(station.batches!.single));
    await settle(tester);
    expect(station.last!.failure, StationFailure.tagLost);
    expect(app.backend.to('POST', '/admin/personalizations/P1'), isEmpty);
    await finish(tester);
  });

  testWidgets('NFC switched off: the run does not start', (WidgetTester tester) async {
    await started(tester);
    app.nfc.available = NfcAvailability.disabled;

    unawaited(station.choose(station.batches!.single));
    await settle(tester);

    expect(station.batch, isNull);
    expect(station.last!.failure, StationFailure.nfcOff);
    expect(app.nfc.prompts, isEmpty);
    await finish(tester);
  });

  testWidgets('a second tap on the batch row starts no second run on the one reader', (WidgetTester tester) async {
    await started(tester);
    final StationBatch batch = station.batches!.single;

    unawaited(station.choose(batch));
    unawaited(station.choose(batch));
    await settle(tester);
    unawaited(station.choose(batch));
    await settle(tester);

    expect(app.nfc.prompts, hasLength(1), reason: 'one reader session, never "busy"');
    expect(station.phase, StationPhase.waiting);
    expect(station.last, isNull);
    await finish(tester);
  });
}

