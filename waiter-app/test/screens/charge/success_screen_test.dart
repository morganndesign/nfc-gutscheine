import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/screens/s09_success.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'charge_harness.dart';

/// S09 Success and "Show guest" (03b §4).
void main() {
  Future<(TestApp, List<(String, bool)>)> redeemed(
    WidgetTester tester, {
    bool isIos = false,
    int amount = 2490,
    int balanceAfter = 2510,
    Locale locale = const Locale('en'),
    Size size = const Size(393, 852),
    Map<String, Object> prefs = const <String, Object>{},
  }) async {
    final TestApp app = await openCharge(
      tester,
      isIos: isIos,
      locale: locale,
      size: size,
      prefs: prefs,
    );
    app.backend.on(
      'POST',
      redeemPath,
      FakeReply(
        201,
        Payloads.redeemed(amount: amount, balanceAfter: balanceAfter),
      ),
    );
    await typeDigits(tester, '$amount');
    final List<(String, bool)> said = recordAnnouncements(tester);
    await tester.tap(
      find.ancestor(
        of: rich(locale.languageCode == 'en' ? 'Redeem' : ','),
        matching: find.byType(PrimaryButton),
      ),
    );
    await settle(tester);
    expect(app.loop.state, isA<SuccessState>());
    return (app, said);
  }

  testWidgets('Android: result, remaining balance, hint, "Show guest" and '
      '"Done"; announced at t = 0; the chime plays once', (
    WidgetTester tester,
  ) async {
    final (TestApp app, List<(String, bool)> said) = await redeemed(tester);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(SuccessScreen), findsOneWidget);
    expect(find.byType(SuccessMark), findsOneWidget);
    expect(find.byType(CountdownHairline), findsOneWidget);
    expect(rich('Redeemed'), findsOneWidget);
    expect(rich('24,90'), findsWidgets);
    expect(rich('Remaining balance € 25,10'), findsOneWidget);
    expect(rich('Card •••• 6488'), findsOneWidget);
    expect(rich('Just tap the next card'), findsOneWidget);
    expect(rich('Show guest'), findsOneWidget);
    expect(rich('Done'), findsOneWidget);
    expect(rich('Scan next card'), findsNothing);
    expect(
      said,
      contains(('Redeemed 24 euros 90, remaining balance 25 euros 10', true)),
    );
    expect(
      soundCount(app, 'gcw_success'),
      1,
      reason: 'AC-S09-2: SuccessMark does not repeat the controller chime',
    );
    await finishApp(tester, app);
  });

  testWidgets('returns to Ready 4.52 s after the response (AC-S09-3)', (
    WidgetTester tester,
  ) async {
    final (TestApp app, _) = await redeemed(tester);
    await tester.pump(const Duration(milliseconds: 3800));
    expect(app.loop.state, isA<SuccessState>());
    expect(find.byType(CountdownHairline), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);
  });

  testWidgets('with a screen reader the return waits 10.52 s', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final (TestApp app, _) = await redeemed(tester);
    await tester.pump(const Duration(seconds: 9));
    expect(app.loop.state, isA<SuccessState>());
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);
  });

  testWidgets('a tap anywhere returns at once (AC-S09-4); "Done" too', (
    WidgetTester tester,
  ) async {
    TestApp app;
    (app, _) = await redeemed(tester);
    await tester.tapAt(const Offset(200, 150));
    await tester.pump();
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);

    (app, _) = await redeemed(tester);
    await tester.tap(rich('Done'));
    await tester.pump();
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);
  });

  testWidgets('"Show guest" pauses the return, shows no controls and closes '
      'after 20 s (AC-S09-9/10/11)', (WidgetTester tester) async {
    final (TestApp app, _) = await redeemed(tester);
    await tester.tap(rich('Show guest'));
    await settle(tester);
    expect((app.loop.state as SuccessState).presenting, isTrue);
    expect(find.byType(CountdownHairline), findsNothing);
    expect(find.byType(PrimaryButton), findsNothing);
    expect(find.byType(SecondaryButton), findsNothing);
    expect(rich('Remaining balance'), findsOneWidget);
    expect(rich('Trattoria Bella Vista · •••• 6488'), findsOneWidget);
    final double balanceSize = tester
        .getSize(find.textContaining('25,10', findRichText: true))
        .height;
    expect(balanceSize, greaterThanOrEqualTo(40));

    await tester.pump(const Duration(seconds: 10));
    expect(app.loop.state, isA<SuccessState>());
    await tester.pump(const Duration(seconds: 10));
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);
  });

  testWidgets('a tap closes the guest view', (WidgetTester tester) async {
    final (TestApp app, _) = await redeemed(tester);
    await tester.tap(rich('Show guest'));
    await settle(tester);
    await tester.tapAt(const Offset(200, 400));
    await tester.pump();
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);
  });

  testWidgets('full balance: "Card is now empty", no 0,00 (AC-S09-8)', (
    WidgetTester tester,
  ) async {
    final (TestApp app, List<(String, bool)> said) = await redeemed(
      tester,
      amount: 5000,
      balanceAfter: 0,
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(rich('Card is now empty'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'(^|\s)0,00'), findRichText: true),
      findsNothing,
    );
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(said, contains(('Redeemed 50 euros. Card is now empty.', true)));
    await finishApp(tester, app);
  });

  testWidgets('iPhone: "Scan next card" opens the NFC sheet (AC-S09-5)', (
    WidgetTester tester,
  ) async {
    final (TestApp app, _) = await redeemed(tester, isIos: true);
    await tester.pump(const Duration(milliseconds: 600));
    expect(rich('Just tap the next card'), findsNothing);
    expect(rich('Show guest'), findsOneWidget);
    final int sessions = app.nfc.calls
        .where((String c) => c == 'startSession')
        .length;
    await tester.tap(rich('Scan next card'));
    await settle(tester);
    expect(
      app.nfc.calls.where((String c) => c == 'startSession').length,
      sessions + 1,
    );
    expect(app.loop.state, isA<ScanningState>());
    await finishApp(tester, app);
  });

  testWidgets('Android: a new card during the countdown opens S07 for it '
      '(AC-S09-6)', (WidgetTester tester) async {
    final (TestApp app, _) = await redeemed(tester);
    app.nfc.emit(
      NfcTagRead(uid: '04:00:00:00:00:00:09', url: Payloads.cardUrl()),
    );
    await settle(tester);
    expect(app.loop.state, isA<ChargeState>());
    await finishApp(tester, app);
  });

  testWidgets('compact phone, 200 % text, dark theme and German render '
      'without overflow', (WidgetTester tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final (TestApp app, _) = await redeemed(
      tester,
      locale: const Locale('de'),
      size: const Size(375, 667),
      prefs: const <String, Object>{'theme': 'dark'},
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(rich('Eingelöst'), findsOneWidget);
    expect(rich('Dem Gast zeigen'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await finishApp(tester, app);
  });
}
