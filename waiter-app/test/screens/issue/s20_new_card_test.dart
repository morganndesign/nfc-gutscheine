import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/screens/s05_ready.dart';
import 'package:giftcard_waiter/screens/s20_new_card.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import '../scan/scan_harness.dart';

Future<TestApp> _app({Map<String, Object?>? user, bool isIos = false, FakeTagWriter? writer}) async {
  final TestApp app = await TestApp.create(user: user, isIos: isIos, tagWriter: writer);
  app.services.settings.firstReadDay = app.session.businessDayKey();
  unawaited(app.loop.refreshNfcAvailability());
  return app;
}

Finder get _newCard => text('New gift card');

Future<void> _key(WidgetTester tester, String digit) async {
  await tester.tap(text(digit).last);
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('S05 entry point', () {
    testWidgets('waiters never see "New gift card"', (WidgetTester tester) async {
      final TestApp app = await _app();
      await pumpWaiterApp(tester, app, size: androidFrame);
      expect(find.byType(ReadyScreen), findsOneWidget);
      expect(_newCard, findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('managers and owners see it on Android', (WidgetTester tester) async {
      for (final String role in <String>['manager', 'owner']) {
        final TestApp app = await _app(user: Payloads.manager(role: role));
        await pumpWaiterApp(tester, app, size: androidFrame);
        expect(_newCard, findsOneWidget, reason: role);
        expect(text('Card number'), findsOneWidget, reason: 'redeem actions unchanged');
        expect(text('QR code'), findsOneWidget);
        await finishApp(tester, app);
      }
    });

    testWidgets('a manager sign-in without the issuing abilities does not show it', (WidgetTester tester) async {
      final TestApp app = await _app(user: Payloads.manager(issuing: false));
      await pumpWaiterApp(tester, app, size: androidFrame);
      expect(_newCard, findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('not on iPhone (tags are programmed on Android)', (WidgetTester tester) async {
      final TestApp app = await _app(user: Payloads.manager(), isIos: true);
      await pumpWaiterApp(tester, app, size: iphoneFrame);
      expect(_newCard, findsNothing);
      await finishApp(tester, app);
    });
  });

  testWidgets('sell and program a card: amount → create → tag → card number and balance', (WidgetTester tester) async {
    final FakeTagWriter writer = FakeTagWriter();
    final TestApp app = await _app(user: Payloads.manager(), writer: writer);
    app.backend
      ..on('POST', '/cards', FakeReply(201, Payloads.issued(value: 5000)))
      ..on('POST', '/cards/${Payloads.newCardId}/nfc/check', FakeReply(200, Payloads.tagCheck()))
      ..on(
        'POST',
        '/cards/${Payloads.newCardId}/nfc',
        FakeReply(200, const <String, Object?>{'data': <String, Object?>{}}),
      );
    await pumpWaiterApp(tester, app, size: androidFrame);

    await tester.tap(_newCard);
    await settle(tester, 12);
    expect(find.byType(NewCardScreen), findsOneWidget);
    expect(app.loop.wantsReaderMode, isFalse, reason: 'card reading paused while S20 is open');

    // A card tapped on the amount screen is not looked up (redemption untouched).
    tapCard(app);
    await settle(tester);
    expect(app.backend.to('POST', '/scan'), isEmpty);

    await _key(tester, '5');
    await _key(tester, '0');
    await _key(tester, '00');
    final Finder create = find.textContaining('Create card', findRichText: true);
    expect(create, findsOneWidget);
    await tester.tap(create);
    await settle(tester, 10);

    expect(app.backend.to('POST', '/cards').single.body!['value'], 5000);
    expect(text('Hold a blank card to the phone'), findsOneWidget);
    expect(text('Card 1268 8343 1352 0042'), findsOneWidget);

    writer.tap();
    await settle(tester, 12);

    expect(text('Card ready'), findsOneWidget);
    expect(text('1268 8343 1352 0042'), findsOneWidget);
    expect(find.textContaining('Balance', findRichText: true), findsOneWidget);
    expect(text('NFC tag written and verified'), findsOneWidget);
    expect(writer.written, Payloads.newCardUrl);

    await tester.tap(text('Done'));
    await settle(tester, 12);
    expect(find.byType(NewCardScreen), findsNothing);
    expect(app.loop.wantsReaderMode, isTrue, reason: 'card reading resumes');
    await finishApp(tester, app);
  });

  testWidgets('tag of another card: problem with "Try again" and "Program later"', (WidgetTester tester) async {
    final FakeTagWriter writer = FakeTagWriter();
    final TestApp app = await _app(user: Payloads.manager(), writer: writer);
    app.backend
      ..on('POST', '/cards', FakeReply(201, Payloads.issued()))
      ..on(
        'POST',
        '/cards/${Payloads.newCardId}/nfc/check',
        FakeReply(
          200,
          Payloads.tagCheck(status: 'refused', reason: 'TAG_LINKED_TO_OTHER_CARD', conflict: '5285 1058 7098 6488'),
        ),
      );
    await pumpWaiterApp(tester, app, size: androidFrame);
    await tester.tap(_newCard);
    await settle(tester, 12);
    await _key(tester, '5');
    await _key(tester, '00');
    await tester.tap(find.textContaining('Create card', findRichText: true));
    await settle(tester, 10);
    writer.tap();
    await settle(tester, 12);

    expect(text('Tag not programmed'), findsOneWidget);
    expect(text('This tag belongs to card 5285 1058 7098 6488. Use a blank tag.'), findsOneWidget);
    expect(writer.written, isNull);

    await tester.tap(text('Program later'));
    await settle(tester, 12);
    expect(text('No tag yet. Program it later in the dashboard.'), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('"not allowed" (403) stays on S20; the app is not blocked', (WidgetTester tester) async {
    final TestApp app = await _app(user: Payloads.manager());
    app.backend.on('POST', '/cards', FakeReply(403, Payloads.error('FORBIDDEN')));
    await pumpWaiterApp(tester, app, size: androidFrame);
    await tester.tap(_newCard);
    await settle(tester, 12);
    await _key(tester, '5');
    await _key(tester, '00');
    await tester.tap(find.textContaining('Create card', findRichText: true));
    await settle(tester, 12);

    expect(text('Not allowed'), findsOneWidget);
    await tester.tap(text('Close').last);
    await settle(tester, 12);
    expect(find.byType(ReadyScreen), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets('German copy', (WidgetTester tester) async {
    final TestApp app = await _app(user: Payloads.manager());
    await pumpWaiterApp(tester, app, size: androidFrame, locale: const Locale('de'));
    expect(text('Neue Gutscheinkarte'), findsOneWidget);
    await tester.tap(text('Neue Gutscheinkarte'));
    await settle(tester, 12);
    expect(text('Kartenwert'), findsOneWidget);
    expect(text('E-Mail des Gastes (optional)'), findsOneWidget);
    await finishApp(tester, app);
  });

  test('writer events never reach the redemption loop', () async {
    final TestApp app = await _app(user: Payloads.manager());
    app.nfc.emit(const NfcWriterTag(uid: sampleUid, url: null));
    await pumpEventQueue();
    expect(app.backend.to('POST', '/scan'), isEmpty);
    app.dispose();
  });
}
