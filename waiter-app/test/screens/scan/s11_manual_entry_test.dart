import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/state/loop_state.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';
import 'package:giftcard_waiter/screens/s11_manual_entry.dart';

import '../../support/app_harness.dart';
import '../../support/screen_harness.dart';
import 'scan_harness.dart';

const String _number = '5285105870986488';

Finder _key(String label) =>
    find.descendant(of: find.byType(Keypad), matching: text(label));

Future<void> _type(WidgetTester tester, String digits) async {
  for (final String d in digits.split('')) {
    await tester.tap(_key(d));
    await tester.pump(const Duration(milliseconds: 80));
  }
}

Future<TestApp> _openManual(
  WidgetTester tester, {
  Size size = iphoneFrame,
  Locale locale = const Locale('en'),
}) async {
  final TestApp app = await TestApp.create();
  await pumpWaiterApp(tester, app, size: size, locale: locale);
  app.loop.openManual();
  await settle(tester);
  expect(find.byType(ManualEntryScreen), findsOneWidget);
  return app;
}

PrimaryButton _submit(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton));

void main() {
  testWidgets(
    'layout: helper, empty field, counter, keypad without 00, disabled button',
    (WidgetTester tester) async {
      final TestApp app = await _openManual(tester);
      expect(text('16 digits on the back of the card'), findsOneWidget);
      expect(text('0 of 16'), findsOneWidget);
      expect(text('Look up card'), findsOneWidget);
      expect(
        _key('00'),
        findsNothing,
        reason: 'card-number keypad has an empty cell (05 §2.1)',
      );
      expect(_submit(tester).onPressed, isNull);
      final Rect button = tester.getRect(find.byType(PrimaryButton));
      expect(button.top, greaterThan(iphoneFrame.height * 0.55));
      await finishApp(tester, app);
    },
  );

  testWidgets(
    '16 digits enable the button, 17th is rejected, submit sends method manual',
    (WidgetTester tester) async {
      final TestApp app = await _openManual(tester);
      app.backend.on(
        'POST',
        '/scan',
        FakeReply(200, Payloads.scan(), const Duration(milliseconds: 400)),
      );
      await _type(tester, _number.substring(0, 15));
      expect(text('15 of 16'), findsOneWidget);
      expect(_submit(tester).onPressed, isNull);
      await _type(tester, _number.substring(15));
      await settle(tester);
      expect(text('16 of 16'), findsOneWidget);
      expect(_submit(tester).onPressed, isNotNull);

      await _type(tester, '1');
      await settle(tester);
      expect(text('16 of 16'), findsOneWidget);

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(app.loop.state, isA<LookingUpState>());
      expect(_submit(tester).status, ButtonStatus.loading);
      // Keypad ignores input while looking up (keys stay at full colour).
      await tester.tap(_key('0'));
      await tester.pump();
      expect(text('16 of 16'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);
      expect(app.loop.state, isA<ChargeState>());
      final Map<String, Object?> body = app.backend
          .to('POST', '/scan')
          .single
          .body!;
      expect(body['method'], 'manual');
      expect(body['card_number'], _number);
      await finishApp(tester, app);
    },
  );

  testWidgets('long-press ⌫ clears the field', (WidgetTester tester) async {
    final TestApp app = await _openManual(tester);
    await _type(tester, '5285');
    final TestGesture press = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('Delete')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await press.up();
    await settle(tester);
    expect(text('0 of 16'), findsOneWidget);
    await finishApp(tester, app);
  });

  testWidgets(
    'paste strips non-digits; an invalid paste shows the error for 3 s',
    (WidgetTester tester) async {
      String clipboard = '5285-1058-7098-6488';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          return call.method == 'Clipboard.getData'
              ? <String, Object?>{'text': clipboard}
              : null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final TestApp app = await _openManual(tester);

      Future<void> paste() async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await settle(tester);
      }

      await paste();
      expect(text('16 of 16'), findsOneWidget);

      await tester.longPress(find.bySemanticsLabel('Delete'));
      await settle(tester);
      clipboard = '12 34';
      await paste();
      expect(text('No valid card number to paste'), findsOneWidget);
      expect(
        text('0 of 16'),
        findsNothing,
        reason: 'the error replaces the counter',
      );
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      expect(text('No valid card number to paste'), findsNothing);
      expect(text('0 of 16'), findsOneWidget);
      await finishApp(tester, app);
    },
  );

  testWidgets(
    '422 VALIDATION_FAILED: inline error, digits kept, cleared by typing',
    (WidgetTester tester) async {
      final TestApp app = await _openManual(tester);
      app.backend.on(
        'POST',
        '/scan',
        FakeReply(422, Payloads.error('VALIDATION_FAILED')),
      );
      await _type(tester, _number);
      await tester.tap(find.byType(PrimaryButton));
      await settle(tester);
      expect(app.loop.state, isA<ManualEntryState>());
      expect(text('Check the card number'), findsOneWidget);
      expect(text('16 of 16'), findsNothing);
      expect(_submit(tester).onPressed, isNotNull, reason: 'digits are kept');

      await tester.tap(find.bySemanticsLabel('Delete'));
      await settle(tester);
      expect(text('Check the card number'), findsNothing);
      expect(text('15 of 16'), findsOneWidget);
      await finishApp(tester, app);
    },
  );

  testWidgets('hardware digits and Enter submit', (WidgetTester tester) async {
    final TestApp app = await _openManual(tester);
    app.backend.on('POST', '/scan', FakeReply(200, Payloads.scan()));
    for (final String d in _number.split('')) {
      await tester.sendKeyEvent(
        LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + int.parse(d)),
      );
    }
    await settle(tester);
    expect(text('16 of 16'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    expect(app.backend.to('POST', '/scan'), hasLength(1));
    await finishApp(tester, app);
  });

  testWidgets('not found → "Edit number" restores the digits', (
    WidgetTester tester,
  ) async {
    final TestApp app = await _openManual(tester);
    app.backend.on(
      'POST',
      '/scan',
      FakeReply(404, Payloads.error('CARD_NOT_FOUND')),
    );
    await _type(tester, _number);
    await tester.tap(find.byType(PrimaryButton));
    await settle(tester);
    expect(app.loop.state, isA<ProblemState>());
    app.loop.editNumber();
    await settle(tester);
    expect(text('16 of 16'), findsOneWidget);
    expect(_submit(tester).onPressed, isNotNull);
    await finishApp(tester, app);
  });

  testWidgets('slow lookup: "Still looking …" and Cancel', (
    WidgetTester tester,
  ) async {
    final TestApp app = await _openManual(tester);
    app.backend.on(
      'POST',
      '/scan',
      FakeReply.hang(const Duration(seconds: 30)),
    );
    await _type(tester, _number);
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
    expect(text('Still looking …'), findsOneWidget);
    await tester.tap(text('Cancel'));
    await settle(tester);
    expect(
      app.loop.state,
      isA<ManualEntryState>(),
      reason: 'Cancel returns to S11 with the digits',
    );
    expect((app.loop.state as ManualEntryState).prefill, hasLength(16));
    await finishApp(tester, app);
  });

  testWidgets('offline: button disabled with the offline caption', (
    WidgetTester tester,
  ) async {
    final TestApp app = await _openManual(tester);
    await _type(tester, _number);
    app.connectivity.setOnline(false);
    await settle(tester);
    expect(text('No connection'), findsOneWidget);
    expect(_submit(tester).onPressed, isNull);
    await finishApp(tester, app);
  });

  testWidgets('close returns to Ready and discards the digits', (
    WidgetTester tester,
  ) async {
    final TestApp app = await _openManual(tester);
    await _type(tester, '52');
    await tester.tap(find.bySemanticsLabel('Close'));
    await settle(tester);
    expect(app.loop.state, isA<ReadyState>());
    await finishApp(tester, app);
  });

  testWidgets('German copy and grouped read-out', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final TestApp app = await _openManual(tester, locale: const Locale('de'));
    expect(text('16 Ziffern auf der Rückseite der Karte'), findsOneWidget);
    expect(text('Karte suchen'), findsOneWidget);
    await _type(tester, '52851058');
    expect(text('8 von 16'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Kartennummer')), findsWidgets);
    await finishApp(tester, app);
    handle.dispose();
  });

  for (final (String name, Size size, double scale) in <(String, Size, double)>[
    ('compact height', compactFrame, 1),
    ('compact height at 200 % text', compactFrame, 2),
    ('tablet landscape (two panes)', tabletLandscape, 1),
    ('tablet landscape at 200 % text', tabletLandscape, 2),
  ]) {
    testWidgets('$name lays out without overflow', (WidgetTester tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final TestApp app = await _openManual(tester, size: size);
      expect(tester.takeException(), isNull);
      // Keys 72 pt, 64 at compact height, 80 on tablets: 4 rows + 3 gaps
      // of 8 (03a §7).
      expect(
        tester.getSize(find.byType(Keypad)).height,
        size == tabletLandscape
            ? 344
            : size.height < 700
            ? 280
            : 312,
      );
      if (size == tabletLandscape) {
        expect(
          tester.getCenter(find.byType(Keypad)).dx,
          greaterThan(size.width / 2),
        );
      }
      await finishApp(tester, app);
    });
  }

  testWidgets('dark theme', (WidgetTester tester) async {
    final TestApp app = await TestApp.create(
      prefs: const <String, Object>{'theme': 'dark'},
    );
    await pumpWaiterApp(tester, app);
    app.loop.openManual();
    await settle(tester);
    expect(
      tester.element(find.byType(ManualEntryScreen)).waiter.brightness,
      Brightness.dark,
    );
    await finishApp(tester, app);
  });
}
