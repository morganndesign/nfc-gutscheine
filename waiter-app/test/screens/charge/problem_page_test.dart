import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/screens/s10_problem.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'charge_harness.dart';

/// S10 variants (03b §5, 12 §3.1 L01–L07).
void main() {
  Future<TestApp> problem(
    WidgetTester tester,
    FakeReply reply, {
    FakeReply? then,
    bool isIos = false,
    bool sun = false,
    Locale locale = const Locale('en'),
  }) async {
    final TestApp app = await startApp(tester, isIos: isIos, locale: locale);
    app.backend.on('POST', '/scan', reply);
    if (then != null) app.backend.on('POST', '/scan', then);
    if (isIos) {
      await readCard(tester, app);
    } else {
      app.nfc.emit(
        NfcTagRead(
          uid: cardUid,
          url: Payloads.cardUrl(sun: sun),
        ),
      );
      await settle(tester);
    }
    expect(app.loop.state, isA<ProblemState>());
    expect(find.byType(ProblemPage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    return app;
  }

  Finder primary() => find.byType(PrimaryButton);

  VoidCallback? onPrimary(WidgetTester tester) =>
      tester.widget<PrimaryButton>(primary()).onPressed;

  testWidgets('not found: scan again / enter card number, support code '
      '(L01)', (WidgetTester tester) async {
    final TestApp app = await problem(
      tester,
      FakeReply(404, Payloads.error('CARD_NOT_FOUND')),
    );
    expect(rich('Card not found'), findsOneWidget);
    expect(rich('This card is not in the system.'), findsOneWidget);
    expect(rich('Scan again'), findsOneWidget);
    expect(rich('Enter card number'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Code [0-9A-F]{6}$'), findRichText: true),
      findsOneWidget,
    );
    expect(soundCount(app, 'gcw_error'), 1, reason: 'E25 once');

    await tester.tap(rich('Enter card number'));
    await settle(tester);
    expect(app.loop.state, isA<ManualEntryState>());
    await finishApp(tester, app);
  });

  testWidgets('not found after manual entry: "Edit number" keeps the digits '
      '(L02)', (WidgetTester tester) async {
    final TestApp app = await startApp(tester);
    app.backend.on(
      'POST',
      '/scan',
      FakeReply(404, Payloads.error('CARD_NOT_FOUND')),
    );
    app.loop
      ..openManual()
      ..submitManual('5285105870986488');
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(rich('No card with this number. Check the digits.'), findsOne);
    expect(rich('Enter card number'), findsNothing);
    await tester.tap(rich('Edit number'));
    await settle(tester);
    final LoopState state = app.loop.state;
    expect(state, isA<ManualEntryState>());
    expect((state as ManualEntryState).prefill, '5285105870986488');
    await finishApp(tester, app);
  });

  testWidgets('another restaurant: Done → Ready (L03)', (
    WidgetTester tester,
  ) async {
    final TestApp app = await problem(
      tester,
      FakeReply(403, Payloads.error('CARD_FOREIGN_RESTAURANT')),
    );
    expect(rich('Card from another restaurant'), findsOneWidget);
    expect(rich('It can only be redeemed at the restaurant'), findsOneWidget);
    await tester.tap(rich('Done'));
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);
  });

  testWidgets('verification failed: calm, neutral tag, one fresh read, then '
      'no second "Scan again" (L04, 13 · R03)', (WidgetTester tester) async {
    final TestApp app = await problem(
      tester,
      FakeReply(403, Payloads.error('NFC_UID_MISMATCH')),
    );
    expect(rich('Card could not be verified'), findsOneWidget);
    expect(
      find.textContaining(
        RegExp(r'^Code [0-9A-F]{6} · UID$'),
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(rich('fraud'), findsNothing);
    expect(rich('Enter card number'), findsNothing, reason: 'never a bypass');
    expect(find.byType(TertiaryButton), findsOneWidget);
    expect(soundCount(app, 'gcw_error'), 1, reason: 'E25 once');

    await tester.tap(find.byType(TertiaryButton));
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    await tester.pump(const Duration(seconds: 3));
    app.nfc.emit(NfcTagRead(uid: cardUid, url: Payloads.cardUrl()));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect((app.loop.state as ProblemState).verifyRescanUsed, isTrue);
    expect(rich('Card could not be verified'), findsOneWidget);
    expect(find.byType(TertiaryButton), findsNothing);
    await finishApp(tester, app);
  });

  testWidgets('throttled: disabled countdown button enables at 0 '
      '(L05, AC-S10-4)', (WidgetTester tester) async {
    final TestApp app = await problem(
      tester,
      FakeReply(
        429,
        Payloads.error('SCAN_THROTTLED', <String, Object?>{'retry_after': 42}),
      ),
    );
    expect(rich('Too many scans'), findsOneWidget);
    expect(rich('Scan again · 0:42'), findsOneWidget);
    expect(onPrimary(tester), isNull);
    expect(rich('Code '), findsNothing, reason: '12 §2.5');
    final List<(String, bool)> said = recordAnnouncements(tester);

    await tester.pump(const Duration(seconds: 10));
    expect(rich('Scan again · 0:32'), findsOneWidget);
    await tester.pump(const Duration(seconds: 32));
    await settle(tester);
    expect(rich('Scan again · '), findsNothing);
    expect(onPrimary(tester), isNotNull);
    expect(
      said.map(((String, bool) a) => a.$1),
      contains('Scanning available again'),
    );
    await tester.tap(primary());
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);
  });

  testWidgets('network: "Try again" re-sends the identical lookup and keeps '
      'S10 busy until the result (L06, 03b §5.1)', (WidgetTester tester) async {
    final TestApp app = await problem(
      tester,
      FakeReply.transport(),
      then: FakeReply(200, Payloads.scan(), const Duration(seconds: 1)),
    );
    expect(rich('No connection'), findsOneWidget);
    expect(rich('The card could not be checked.'), findsOneWidget);
    expect(rich('Code '), findsNothing);
    expect(soundCount(app, 'gcw_warning'), 1, reason: 'E26 once');
    await tester.tap(rich('Try again'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(app.loop.state, isA<LookingUpState>());
    expect(find.byType(ProblemPage), findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).status,
      ButtonStatus.loading,
    );
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(app.loop.state, isA<ChargeState>());
    expect(app.backend.to('POST', '/scan'), hasLength(2));
    await finishApp(tester, app);
  });

  testWidgets('network with a SUN-signed card: "Scan again", never a re-post '
      '(AC-S10-5)', (WidgetTester tester) async {
    final TestApp app = await problem(tester, FakeReply.transport(), sun: true);
    expect(rich('Try again'), findsNothing);
    await tester.tap(rich('Scan again'));
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    expect(app.backend.to('POST', '/scan'), hasLength(1));
    await finishApp(tester, app);
  });

  testWidgets('server error: "Try again" with support code (L07)', (
    WidgetTester tester,
  ) async {
    final TestApp app = await problem(
      tester,
      FakeReply(503, Payloads.error('SERVICE_UNAVAILABLE')),
    );
    expect(rich('Service not available right now'), findsOneWidget);
    expect(rich('The problem is not the card.'), findsOneWidget);
    expect(find.text('Try again', findRichText: true), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Code '), findRichText: true),
      findsOne,
    );
    await finishApp(tester, app);
  });

  testWidgets('long-press on the support code copies the full request id '
      '(AC-S10-6)', (WidgetTester tester) async {
    final List<String> copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add(
            (call.arguments as Map<Object?, Object?>)['text']! as String,
          );
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final TestApp app = await problem(
      tester,
      FakeReply(404, Payloads.error('CARD_NOT_FOUND')),
    );
    final String code = (app.loop.state as ProblemState).supportCode!;
    await tester.longPress(rich('Code $code'));
    await settle(tester);
    expect(copied, hasLength(1));
    expect(copied.single.length, greaterThan(code.length));
    expect(copied.single.replaceAll('-', '').toUpperCase(), endsWith(code));
    await finishApp(tester, app);
  });

  testWidgets('✕ returns to Ready', (WidgetTester tester) async {
    final TestApp app = await problem(
      tester,
      FakeReply(404, Payloads.error('CARD_NOT_FOUND')),
    );
    await tester.tap(closeButton);
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);
  });

  testWidgets('iPhone: "Scan again" opens the NFC sheet', (
    WidgetTester tester,
  ) async {
    final TestApp app = await problem(
      tester,
      FakeReply(404, Payloads.error('CARD_NOT_FOUND')),
      isIos: true,
    );
    final int sessions = app.nfc.calls
        .where((String c) => c == 'startSession')
        .length;
    await tester.tap(rich('Scan again'));
    await settle(tester);
    expect(
      app.nfc.calls.where((String c) => c == 'startSession').length,
      sessions + 1,
    );
    await finishApp(tester, app);
  });

  testWidgets('German and BHS copy', (WidgetTester tester) async {
    TestApp app = await problem(
      tester,
      FakeReply(404, Payloads.error('CARD_NOT_FOUND')),
      locale: const Locale('de'),
    );
    expect(rich('Karte nicht gefunden'), findsOneWidget);
    await finishApp(tester, app);

    app = await problem(
      tester,
      FakeReply(404, Payloads.error('CARD_NOT_FOUND')),
      locale: const Locale('bs'),
    );
    expect(rich('Kartica nije pronađena'), findsOneWidget);
    await finishApp(tester, app);
  });
}
