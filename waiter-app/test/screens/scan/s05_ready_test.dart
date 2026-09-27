import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/platform/nfc_service.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/screens/s05_ready.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'scan_harness.dart';

/// [readToday] false keeps the V8 first-card tip (no read since 04:00).
Future<TestApp> _android({
  NfcAvailability nfc = NfcAvailability.enabled,
  Map<String, Object> prefs = const <String, Object>{},
  bool readToday = true,
}) async {
  final TestApp app = await TestApp.create(prefs: prefs);
  _prepare(app, nfc, readToday);
  return app;
}

Future<TestApp> _iphone({
  NfcAvailability nfc = NfcAvailability.enabled,
  bool readToday = true,
}) async {
  final TestApp app = await TestApp.create(isIos: true);
  _prepare(app, nfc, readToday);
  return app;
}

void _prepare(TestApp app, NfcAvailability nfc, bool readToday) {
  if (readToday) {
    app.services.settings.firstReadDay = app.session.businessDayKey();
  }
  app.nfc.value = nfc;
  unawaited(app.loop.refreshNfcAvailability());
}

void main() {
  group('S05 Android · V1 listening', () {
    testWidgets('TopBar, instruction and the two alternatives (EN)', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android();
      await pumpWaiterApp(tester, app, size: androidFrame);

      expect(find.byType(ReadyScreen), findsOneWidget);
      expect(text('Trattoria Bella Vista'), findsOneWidget);
      expect(find.bySemanticsLabel('Recent'), findsOneWidget);
      expect(find.bySemanticsLabel('Menu, Anna Berger'), findsOneWidget);
      expect(text('Hold the card to the phone'), findsOneWidget);
      expect(text('The card is detected automatically'), findsOneWidget);
      expect(text('Card number'), findsOneWidget);
      expect(text('QR code'), findsOneWidget);
      expect(
        text('Scan card'),
        findsNothing,
        reason: 'Android Ready has no PrimaryButton (03a §5.19)',
      );
      expect(find.byType(NfcScanAnimation), findsOneWidget);
      expect(app.nfc.calls, contains('readerMode:true'));
      await finishApp(tester, app);
    });

    testWidgets('German and BHS copy', (WidgetTester tester) async {
      final TestApp de = await _android();
      await pumpWaiterApp(
        tester,
        de,
        locale: const Locale('de'),
        size: androidFrame,
      );
      expect(text('Karte an das Handy halten'), findsOneWidget);
      expect(text('Die Karte wird automatisch erkannt'), findsOneWidget);
      expect(text('Kartennummer'), findsOneWidget);
      expect(text('QR-Code'), findsOneWidget);
      await finishApp(tester, de);

      final TestApp bs = await _android();
      await pumpWaiterApp(
        tester,
        bs,
        locale: const Locale('bs'),
        size: androidFrame,
      );
      expect(text('Prislonite karticu uz telefon'), findsOneWidget);
      expect(text('Kartica se automatski prepoznaje'), findsOneWidget);
      expect(text('Broj kartice'), findsOneWidget);
      await finishApp(tester, bs);
    });

    testWidgets('card read → looking up → skeleton after 150 ms → Charge', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android();
      app.backend.on(
        'POST',
        '/scan',
        FakeReply(200, Payloads.scan(), const Duration(milliseconds: 600)),
      );
      await pumpWaiterApp(tester, app, size: androidFrame);

      tapCard(app);
      await tester.pump();
      expect(text('Looking up card\u00a0…'), findsOneWidget);
      expect(app.loop.state, isA<LookingUpState>());
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byType(BalanceCard),
        findsNothing,
        reason: 'never a skeleton before 150 ms',
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(BalanceCard), findsOneWidget);
      final Iterable<MethodCall> scan = app.feedbackCalls.where(
        (MethodCall c) => c.method == 'sound',
      );
      expect(
        scan,
        hasLength(1),
        reason: 'the loop plays card-detected once; S05 adds nothing',
      );

      await tester.pump(const Duration(milliseconds: 600));
      await settle(tester);
      expect(app.loop.state, isA<ChargeState>());
      expect(app.backend.to('POST', '/scan').single.body!['method'], 'nfc');
      await finishApp(tester, app);
    });

    testWidgets('slow lookup: "Still looking …" at 3 s, Cancel returns to V1', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android();
      app.backend.on(
        'POST',
        '/scan',
        FakeReply.hang(const Duration(seconds: 30)),
      );
      await pumpWaiterApp(tester, app, size: androidFrame);

      tapCard(app);
      await settle(tester);
      expect(text('Cancel'), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(text('Still looking\u00a0…'), findsOneWidget);
      expect(text('Cancel'), findsOneWidget);

      await tester.tap(text('Cancel'));
      await settle(tester);
      expect(app.loop.state, isA<ReadyState>());
      await tester.pump(const Duration(milliseconds: 400));
      expect(text('Hold the card to the phone'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('three failed reads show the hold-still hint for 2 s', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android();
      await pumpWaiterApp(tester, app, size: androidFrame);
      for (int i = 0; i < 3; i++) {
        app.nfc.emit(const NfcReadFailed());
      }
      await settle(tester);
      expect(text("Couldn't read the card"), findsOneWidget);
      expect(text('Hold it still for a second.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(text('Hold the card to the phone'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('a tag that is not a gift card sends no request', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android();
      await pumpWaiterApp(tester, app, size: androidFrame);
      tapCard(app, url: foreignUrl);
      await settle(tester);
      expect(text('This is not a gift card'), findsOneWidget);
      expect(app.backend.to('POST', '/scan'), isEmpty);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(text('Hold the card to the phone'), findsOneWidget);
      await finishApp(tester, app);
    });
  });

  group('S05 · V8 first card of the shift', () {
    testWidgets('Android: tip replaces the hint until the first read today', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android(readToday: false);
      app.backend.on('POST', '/scan', FakeReply(200, Payloads.scan()));
      await pumpWaiterApp(tester, app, size: androidFrame);
      expect(
        text(
          'Tip: the NFC antenna is usually at the top of the back, near the camera.',
        ),
        findsOneWidget,
      );
      expect(text('The card is detected automatically'), findsNothing);

      tapCard(app);
      await settle(tester);
      app.loop.back();
      await settle(tester, 10);
      expect(text('The card is detected automatically'), findsOneWidget);
      expect(find.textContaining('Tip:', findRichText: true), findsNothing);
      await finishApp(tester, app);
    });

    testWidgets('iPhone: tip in place of the hint', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _iphone(readToday: false);
      await pumpWaiterApp(tester, app);
      expect(
        text('Tip: hold the card flat against the top edge, near the camera.'),
        findsOneWidget,
      );
      await finishApp(tester, app);
    });
  });

  group('S05 · V6 offline', () {
    testWidgets(
      'enters after 2 s, disables scan entry points, recovers with "Connected again"',
      (WidgetTester tester) async {
        final TestApp app = await _android();
        await pumpWaiterApp(tester, app, size: androidFrame);

        app.connectivity.setOnline(false);
        await settle(tester);
        expect(
          text('No connection'),
          findsNothing,
          reason: 'offline needs 2 s of confirmed loss',
        );
        await tester.pump(const Duration(seconds: 2));
        await settle(tester);
        expect(text('No connection'), findsOneWidget);
        expect(
          text('Redeeming needs a connection so nothing is ever booked twice.'),
          findsOneWidget,
        );

        await tester.tap(text('Card number'));
        await settle(tester);
        expect(
          app.loop.state,
          isA<ReadyState>(),
          reason: 'Card number is disabled offline',
        );

        app.connectivity.setOnline(true);
        await settle(tester);
        expect(text('Connected again'), findsOneWidget);
        expect(text('Hold the card to the phone'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await finishApp(tester, app);
      },
    );

    testWidgets('a card read before offline is confirmed shows the L09 line', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android();
      await pumpWaiterApp(tester, app, size: androidFrame);
      app.connectivity.setOnline(false);
      await settle(tester, 2);
      tapCard(app);
      await settle(tester, 2);
      expect(
        text('No connection – the card can\'t be checked'),
        findsOneWidget,
      );
      expect(app.backend.to('POST', '/scan'), isEmpty);
      await tester.pump(const Duration(seconds: 3));
      await finishApp(tester, app);
    });

    testWidgets('iPhone offline: Scan card disabled', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _iphone();
      await pumpWaiterApp(tester, app);
      app.connectivity.setOnline(false);
      await tester.pump(const Duration(seconds: 2));
      await settle(tester);
      expect(text('No connection'), findsOneWidget);
      await tester.tap(text('Scan card'));
      await settle(tester);
      expect(app.nfc.calls, isNot(contains('startSession')));
      await finishApp(tester, app);
    });
  });

  group('S05 · S16 NFC states', () {
    testWidgets('V4 NFC off: deep link, then back on with haptic.select', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android(nfc: NfcAvailability.disabled);
      await pumpWaiterApp(tester, app, size: androidFrame);
      expect(text('NFC is off'), findsOneWidget);
      expect(text('Turn on NFC to scan cards.'), findsOneWidget);
      expect(text('Card number'), findsOneWidget);

      await tester.tap(text('Turn on NFC'));
      await settle(tester);
      expect(app.nfc.calls, contains('openSettings'));

      final int before = hapticCount(app);
      app.nfc.value = NfcAvailability.enabled;
      unawaited(app.loop.refreshNfcAvailability());
      await settle(tester);
      expect(text('Hold the card to the phone'), findsOneWidget);
      expect(hapticCount(app), before + 1);
      await finishApp(tester, app);
    });

    testWidgets(
      'NFC off + offline shows NFC off with the offline banner (priority V4 > V6)',
      (WidgetTester tester) async {
        final TestApp app = await _android(nfc: NfcAvailability.disabled);
        await pumpWaiterApp(tester, app, size: androidFrame);
        app.connectivity.setOnline(false);
        await tester.pump(const Duration(seconds: 2));
        await settle(tester);
        expect(text('NFC is off'), findsOneWidget);
        expect(text('No connection'), findsOneWidget);
        await finishApp(tester, app);
      },
    );

    testWidgets('V5 no NFC (Android phone): QR first, no NFC animation', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android(nfc: NfcAvailability.unsupported);
      await pumpWaiterApp(tester, app, size: androidFrame);
      expect(text('Scan the QR code on the card'), findsOneWidget);
      expect(
        text('This device has no NFC. Use the QR code or the card number.'),
        findsOneWidget,
      );
      expect(find.byType(NfcScanAnimation), findsNothing);
      expect(text('QR code'), findsNothing);
      await tester.tap(text('Card number'));
      await settle(tester);
      expect(app.loop.state, isA<ManualEntryState>());
      await finishApp(tester, app);
    });
  });

  group('S05 iPhone · V2', () {
    testWidgets('Scan card opens the system sheet once; timeout hint for 6 s', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _iphone();
      await pumpWaiterApp(tester, app);
      expect(text('Scan card'), findsOneWidget);
      expect(
        text('After tapping, hold the card near the top of the iPhone'),
        findsOneWidget,
      );
      expect(text('Hold the card to the phone'), findsNothing);

      await tester.tap(text('Scan card'));
      await settle(tester);
      expect(app.loop.state, isA<ScanningState>());
      await tester.tap(text('Scan card'));
      await settle(tester);
      expect(
        app.nfc.calls.where((String c) => c == 'startSession'),
        hasLength(1),
      );

      app.nfc.emit(const NfcSessionEnded(NfcSessionEnd.timeout));
      await settle(tester);
      expect(
        text('No card detected. Tap "Scan card" to try again.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      expect(
        text('After tapping, hold the card near the top of the iPhone'),
        findsOneWidget,
      );
      await finishApp(tester, app);
    });

    testWidgets('P09: NFC temporarily unavailable → snackbar', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _iphone();
      await pumpWaiterApp(tester, app);
      await tester.tap(text('Scan card'));
      await settle(tester);
      app.nfc.emit(const NfcSessionEnded(NfcSessionEnd.systemBusy));
      await settle(tester);
      expect(
        text("NFC isn't available right now. Use the card number or QR code."),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 5));
      await finishApp(tester, app);
    });

    testWidgets('Scan card sits below the thumb-zone line', (
      WidgetTester tester,
    ) async {
      for (final Size frame in <Size>[iphoneFrame, compactFrame]) {
        final TestApp app = await _iphone();
        await pumpWaiterApp(tester, app, size: frame);
        final Rect button = tester.getRect(
          find.ancestor(
            of: text('Scan card'),
            matching: find.byType(PrimaryButton),
          ),
        );
        expect(button.top, greaterThan(frame.height * 0.55));
        expect(button.height, frame.height < 700 ? 56 : 64);
        await finishApp(tester, app);
      }
    });

    testWidgets('German copy', (WidgetTester tester) async {
      final TestApp app = await _iphone();
      await pumpWaiterApp(tester, app, locale: const Locale('de'));
      expect(text('Karte scannen'), findsOneWidget);
      expect(
        text('Nach dem Tippen die Karte oben an das iPhone halten'),
        findsOneWidget,
      );
      await finishApp(tester, app);
    });

    testWidgets('iPad: QR-first, secondary above primary, no NFC wording', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _iphone(nfc: NfcAvailability.unsupported);
      await pumpWaiterApp(tester, app, size: tabletLandscape);
      expect(text('Scan QR code'), findsOneWidget);
      expect(
        find.textContaining('NFC', findRichText: true),
        findsOneWidget,
        reason: 'only the no-NFC hint mentions NFC',
      );
      final double manual = tester.getCenter(text('Card number')).dy;
      final double qr = tester.getCenter(text('Scan QR code')).dy;
      expect(manual, lessThan(qr));
      await tester.tap(text('Scan QR code'));
      await settle(tester);
      expect(app.loop.state, isA<QrScanState>());
      await finishApp(tester, app);
    });
  });

  group('S05 · V7 maintenance banner', () {
    testWidgets('shows the server text, never moves the buttons, dismissible', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android();
      app.backend.on(
        'GET',
        '/app/config',
        FakeReply(200, Payloads.config(notice: 'Wartung heute 23:00–23:30.')),
      );
      await pumpWaiterApp(tester, app, size: androidFrame);
      final double buttonsBefore = tester.getRect(text('Card number')).top;

      await tester.pump(const Duration(minutes: 6));
      unawaited(app.session.onForeground());
      await settle(tester);
      expect(text('Wartung heute 23:00–23:30.'), findsOneWidget);
      expect(tester.getRect(text('Card number')).top, buttonsBefore);

      await tester.tap(find.bySemanticsLabel('Dismiss notice'));
      await settle(tester);
      expect(text('Wartung heute 23:00–23:30.'), findsNothing);
      await finishApp(tester, app);
    });
  });

  group('S05 · navigation', () {
    testWidgets('Card number and QR code open S11 / S12', (
      WidgetTester tester,
    ) async {
      mockDeniedCamera();
      final TestApp app = await _android();
      await pumpWaiterApp(tester, app, size: androidFrame);
      await tester.tap(text('Card number'));
      await settle(tester);
      expect(app.loop.state, isA<ManualEntryState>());
      app.loop.back();
      await settle(tester);
      await tester.tap(text('QR code'));
      await settle(tester);
      expect(app.loop.state, isA<QrScanState>());
      await finishApp(tester, app);
    });

    testWidgets('Recent and Menu open sheets and pause reader mode', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android();
      await pumpWaiterApp(tester, app, size: androidFrame);
      await tester.tap(find.bySemanticsLabel('Recent'));
      await settle(tester);
      expect(text('No redemptions yet'), findsOneWidget);
      expect(app.loop.wantsReaderMode, isFalse);
      expect(app.nfc.calls.last, 'readerMode:false');
      await tester.tapAt(const Offset(200, 60));
      await settle(tester);
      expect(app.loop.wantsReaderMode, isTrue);

      app.backend.on(
        'GET',
        '/devices/current',
        FakeReply(200, <String, Object?>{
          'data': <String, Object?>{'name': 'Pixel 7'},
        }),
      );
      await tester.tap(find.bySemanticsLabel('Menu, Anna Berger'));
      await settle(tester);
      expect(text('Sign out'), findsOneWidget);
      expect(app.loop.wantsReaderMode, isFalse);
      await finishApp(tester, app);
    });
  });

  group('S05 · responsive, text size, theme, semantics', () {
    for (final (String name, Size size, bool ios) in <(String, Size, bool)>[
      ('Android compact', compactFrame, false),
      ('iPhone compact', compactFrame, true),
      ('Android tablet landscape', tabletLandscape, false),
    ]) {
      testWidgets('$name at 200 % text lays out without overflow', (
        WidgetTester tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final TestApp app = ios ? await _iphone() : await _android();
        await pumpWaiterApp(tester, app, size: size);
        expect(tester.takeException(), isNull);
        expect(find.byType(SecondaryButton), findsNWidgets(2));
        await finishApp(tester, app);
      });
    }

    testWidgets('secondary buttons stack at 200 % on a compact phone', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final TestApp app = await _android();
      await pumpWaiterApp(
        tester,
        app,
        locale: const Locale('de'),
        size: compactFrame,
      );
      final Rect manual = tester.getRect(
        find.ancestor(
          of: text('Kartennummer'),
          matching: find.byType(SecondaryButton),
        ),
      );
      final Rect qr = tester.getRect(
        find.ancestor(
          of: text('QR-Code'),
          matching: find.byType(SecondaryButton),
        ),
      );
      expect(qr.top, greaterThan(manual.bottom));
      await finishApp(tester, app);
    });

    testWidgets('tablet landscape: content column max 480, centred', (
      WidgetTester tester,
    ) async {
      final TestApp app = await _android();
      await pumpWaiterApp(tester, app, size: tabletLandscape);
      final Rect manual = tester.getRect(
        find.ancestor(
          of: text('Card number'),
          matching: find.byType(SecondaryButton),
        ),
      );
      final Rect qr = tester.getRect(
        find.ancestor(
          of: text('QR code'),
          matching: find.byType(SecondaryButton),
        ),
      );
      expect(qr.right - manual.left, lessThanOrEqualTo(480));
      expect(
        (manual.left + qr.right) / 2,
        closeTo(tabletLandscape.width / 2, 1),
      );
      await finishApp(tester, app);
    });

    testWidgets('dark theme', (WidgetTester tester) async {
      final TestApp app = await _android(
        prefs: const <String, Object>{'theme': 'dark'},
      );
      await pumpWaiterApp(tester, app, size: androidFrame);
      await settle(tester);
      final BuildContext context = tester.element(find.byType(ReadyScreen));
      expect(context.waiter.brightness, Brightness.dark);
      expect(text('Hold the card to the phone'), findsOneWidget);
      await finishApp(tester, app);
    });

    testWidgets('semantics: header + live region title, labelled TopBar', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final TestApp app = await _android();
      await pumpWaiterApp(tester, app, size: androidFrame);
      expect(
        tester.getSemantics(text('Hold the card to the phone')),
        isSemantics(
          label: 'Hold the card to the phone',
          isHeader: true,
          isLiveRegion: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Recent')),
        isSemantics(isButton: true),
      );
      expect(find.bySemanticsLabel('Trattoria Bella Vista'), findsOneWidget);
      await finishApp(tester, app);
      handle.dispose();
    });

    testWidgets('Reduce Motion keeps the rings static', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final TestApp app = await _android();
      await pumpWaiterApp(tester, app, size: androidFrame);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
      await finishApp(tester, app);
    });
  });
}
