import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/l10n/app_localizations.dart';
import 'package:giftcard_waiter/screens/s05_ready.dart';
import 'package:giftcard_waiter/screens/s21_station.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';

/// S21: platform staff sign in as the personalisation station and never see the till.
void main() {
  final AppLocalizations en = lookupAppLocalizations(const Locale('en'));
  Finder text(String value) => find.text(value, findRichText: true);

  testWidgets('station: choose a batch, personalise blanks one after the other, finish', (WidgetTester tester) async {
    final FakeNfcRelay nfc = FakeNfcRelay()..card = null;
    final TestApp app = await TestApp.create(user: Payloads.stationUser(), nfc: nfc);
    app.backend
      ..on('GET', '/auth/me', FakeReply(200, <String, Object?>{'data': Payloads.stationUser()}))
      ..on('GET', '/admin/station/batches', FakeReply(200, Payloads.stationBatches()))
      ..on(
        'POST',
        '/admin/card-batches/b-1/personalizations',
        FakeReply(200, Payloads.round(id: 'P1', commands: <String>['00A4040007D276000085010100'])),
      )
      ..on('POST', '/admin/personalizations/P1', FakeReply(200, Payloads.round(stage: 'done', state: 'qa_passed')));
    await pumpWaiterApp(tester, app);

    expect(find.byType(StationScreen), findsOneWidget);
    expect(find.byType(ReadyScreen), findsNothing);
    expect(text(en.stationChoose), findsOneWidget);
    expect(text('Zum Goldenen Hirschen'), findsOneWidget);
    expect(text(en.stationProgress('2', '50')), findsOneWidget);
    expect(text(en.stationChooseHint), findsOneWidget);

    await tester.tap(text('Zum Goldenen Hirschen'));
    await settle(tester);
    expect(text('B-2026-001'), findsOneWidget);
    expect(text(en.stationWaiting), findsOneWidget);
    expect(nfc.prompts.single, en.stationWaiting);

    nfc.queue.add(FakeCard(uidHex: '04112233445566'));
    nfc.cancelWaiting();
    await settle(tester, 20);
    // The sheet closed without a card (iPhone): back to the list, told why; tapping the batch again starts over.
    expect(text(en.stationChoose), findsOneWidget);
    expect(text(en.stationNoCard), findsOneWidget);
    await tester.tap(text('Zum Goldenen Hirschen'));
    await settle(tester, 20);
    expect(text(en.stationDone('B-2026-001-0003')), findsOneWidget);
    expect(text(en.stationProgress('3', '50')), findsOneWidget);
    expect(text(en.stationWaiting), findsOneWidget);

    await tester.tap(text(en.stationFinish));
    await settle(tester, 20);
    expect(text(en.stationChoose), findsOneWidget);
    expect(nfc.cancels, 1);
    await finishApp(tester, app);
  });

  // Found in the first iPhone test of the station (2026-10-05): a batch of 3 needs an end, not an endless reader.
  for (final bool ios in <bool>[false, true]) {
    testWidgets('${ios ? 'iPhone' : 'Android'}: the last card of a batch ends the run and points to the release', (
      WidgetTester tester,
    ) async {
      final FakeNfcRelay nfc = FakeNfcRelay()..card = null;
      final TestApp app = await TestApp.create(isIos: ios, user: Payloads.stationUser(), nfc: nfc);
      app.backend
        ..on('GET', '/auth/me', FakeReply(200, <String, Object?>{'data': Payloads.stationUser()}))
        ..on('GET', '/admin/station/batches', FakeReply(200, Payloads.stationBatches(ordered: 3, done: 2)))
        ..on(
          'POST',
          '/admin/card-batches/b-1/personalizations',
          FakeReply(200, Payloads.round(id: 'P1', commands: <String>['00A4040007D276000085010100'])),
        )
        ..on('POST', '/admin/personalizations/P1', FakeReply(200, Payloads.round(stage: 'done', state: 'qa_passed')));
      await pumpWaiterApp(tester, app);
      expect(text(en.stationProgress('2', '3')), findsOneWidget);

      nfc.queue.add(FakeCard(uidHex: '04112233445566'));
      await tester.tap(text('Zum Goldenen Hirschen'));
      await settle(tester, 20);
      expect(text(en.stationCompleteTitle), findsOneWidget);
      expect(text(en.stationCompleteBody('3')), findsOneWidget);
      expect(nfc.prompts, hasLength(1), reason: 'no reader for a fourth card');

      await tester.tap(text(en.commonDone));
      await settle(tester, 20);
      expect(text(en.stationChoose), findsOneWidget);
      await finishApp(tester, app);
    });
  }

  testWidgets('a batch that is already complete opens straight to the release hint', (WidgetTester tester) async {
    final FakeNfcRelay nfc = FakeNfcRelay()..card = null;
    final TestApp app = await TestApp.create(user: Payloads.stationUser(), nfc: nfc);
    app.backend
      ..on('GET', '/auth/me', FakeReply(200, <String, Object?>{'data': Payloads.stationUser()}))
      ..on('GET', '/admin/station/batches', FakeReply(200, Payloads.stationBatches(ordered: 3, done: 3)));
    await pumpWaiterApp(tester, app);
    await tester.tap(text('Zum Goldenen Hirschen'));
    await settle(tester, 20);
    expect(text(en.stationCompleteTitle), findsOneWidget);
    expect(nfc.prompts, isEmpty);
    await finishApp(tester, app);
  });

  testWidgets('another phone finished the batch: the server says so and the run ends', (WidgetTester tester) async {
    final FakeNfcRelay nfc = FakeNfcRelay()..card = null;
    final TestApp app = await TestApp.create(user: Payloads.stationUser(), nfc: nfc);
    app.backend
      ..on('GET', '/auth/me', FakeReply(200, <String, Object?>{'data': Payloads.stationUser()}))
      ..on('GET', '/admin/station/batches', FakeReply(200, Payloads.stationBatches(ordered: 3, done: 1)))
      ..on(
        'POST',
        '/admin/card-batches/b-1/personalizations',
        FakeReply(422, Payloads.error('CARD_PERSONALIZATION_FAILED', <String, Object?>{'reason': 'batch_complete'})),
      );
    await pumpWaiterApp(tester, app);
    nfc.queue.add(FakeCard(uidHex: '04112233445566'));
    await tester.tap(text('Zum Goldenen Hirschen'));
    await settle(tester, 20);
    expect(text(en.stationCompleteTitle), findsOneWidget);
    expect(nfc.prompts, hasLength(1));
    await finishApp(tester, app);
  });
}
