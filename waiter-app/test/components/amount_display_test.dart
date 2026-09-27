import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import 'harness.dart';

/// The amount glyphs (not the message slot).
Finder _glyphs() => find.descendant(
  of: find.descendant(
    of: find.byType(AmountDisplay),
    matching: find.byType(AnimatedPositioned),
  ),
  matching: find.byType(RichText),
);

/// Visible glyphs of the display, left to right.
String _visible(WidgetTester tester) {
  final List<RichText> glyphs = tester.widgetList<RichText>(_glyphs()).toList();
  final List<(double, String)> placed = <(double, String)>[
    for (final RichText g in glyphs)
      (tester.getTopLeft(find.byWidget(g)).dx, g.text.toPlainText()),
  ]..sort(((double, String) a, (double, String) b) => a.$1.compareTo(b.$1));
  return placed.map(((double, String) p) => p.$2).join();
}

Widget _display(
  String digits, {
  AmountDisplayState state = AmountDisplayState.entering,
  String? message,
  Widget? chip,
  String? announcement,
  ShakeController? shake,
}) => AmountDisplay(
  digits: digits,
  money: testMoney,
  state: state,
  message: message,
  chip: chip,
  overBalanceAnnouncement: announcement,
  shakeController: shake,
);

void main() {
  setUpAll(loadWaiterFonts);

  for (final Brightness b in bothThemes) {
    testWidgets('placeholder € 0,00 in fg.tertiary ($b)', (
      WidgetTester tester,
    ) async {
      await pumpComponent(tester, _display(''), brightness: b);
      expect(_visible(tester), '€0,00');
      final WaiterColors c = WaiterColors.resolve(b);
      for (final RichText g in tester.widgetList<RichText>(_glyphs())) {
        expect(g.text.style!.color, c.fgTertiary);
      }
    });
  }

  testWidgets('POS entry: digits shift in from the right', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, _display('2'));
    expect(_visible(tester), '€0,02');
    await pumpComponent(tester, _display('24'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_visible(tester), '€0,24');
    await pumpComponent(tester, _display('2490'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_visible(tester), '€24,90');
    await pumpComponent(tester, _display('249'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_visible(tester), '€2,49');
  });

  testWidgets('semantics: "Amount {spoken}", debounced 400 ms', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(tester, _display(''));
    expect(
      tester.getSemantics(find.bySemanticsLabel('Amount 0 euros')),
      isSemantics(label: 'Amount 0 euros', isLiveRegion: true),
    );
    await pumpComponent(tester, _display('24'));
    await pumpComponent(tester, _display('249'));
    await pumpComponent(tester, _display('2490'));
    expect(
      find.bySemanticsLabel('Amount 0 euros'),
      findsOneWidget,
      reason: 'still debouncing',
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.bySemanticsLabel('Amount 24 euros 90'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('never truncates € 99.999,99 at 200 % on a 320-pt phone', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      _display('9999999'),
      textScale: 2,
      size: const Size(320, 568),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(_visible(tester), '€99.999,99');
    final Rect box = tester.getRect(find.byType(AmountDisplay));
    for (final Element e in _glyphs().evaluate()) {
      final Rect glyph = tester.getRect(find.byWidget(e.widget));
      expect(glyph.left, greaterThanOrEqualTo(box.left - 0.5));
      expect(glyph.right, lessThanOrEqualTo(box.right + 0.5));
    }
    final RichText digit = tester.widgetList<RichText>(_glyphs()).last;
    expect(
      digit.text.style!.fontSize,
      greaterThanOrEqualTo(TypeTokens.amountXl.minSizeAfterShrink!),
    );
  });

  testWidgets('over balance: danger colour, message, warning, shake', (
    WidgetTester tester,
  ) async {
    final FeedbackRecorder feedback = FeedbackRecorder();
    addTearDown(feedback.dispose);
    await pumpComponent(tester, _display('3000'), feedback: feedback.service);
    await pumpComponent(
      tester,
      _display(
        '4000',
        state: AmountDisplayState.overBalance,
        message: '€ 7,50 more than the balance',
        announcement: '7 euros 50 more than the balance.',
        chip: QuickAmountChip(cents: 3250, money: testMoney, onPressed: () {}),
      ),
      feedback: feedback.service,
    );
    await tester.pump(const Duration(milliseconds: 30));
    expect(feedback.haptics, <String>['waveform'], reason: 'haptic.warning');
    final Transform shaking = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(AmountDisplay),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(shaking.transform.getTranslation().x, isNot(0));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('€ 7,50 more than the balance', findRichText: true),
      findsOneWidget,
    );
    expect(find.byType(QuickAmountChip), findsOneWidget);
    expect(
      tester.getSize(find.byType(QuickAmountChip)).height,
      greaterThanOrEqualTo(Sizes.targetMin),
    );
    final WaiterColors c = WaiterColors.resolve(Brightness.light);
    final RichText digit = tester.widgetList<RichText>(_glyphs()).first;
    expect(digit.text.style!.color, c.danger);
  });

  testWidgets('limit nudge is ±3 pt; none under Reduce Motion', (
    WidgetTester tester,
  ) async {
    final ShakeController shake = ShakeController();
    addTearDown(shake.dispose);
    await pumpComponent(tester, _display('1234567', shake: shake));
    shake.nudge();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    Transform t = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(AmountDisplay),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(t.transform.getTranslation().x, closeTo(3, 0.01));
    await tester.pump(const Duration(milliseconds: 300));

    await pumpComponent(
      tester,
      _display('1234567', shake: shake),
      reduceMotion: true,
    );
    shake.nudge();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    t = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(AmountDisplay),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(t.transform.getTranslation().x, 0);
  });

  testWidgets('Reduce Motion: value replaced by a cross-fade', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, _display('2'), reduceMotion: true);
    await pumpComponent(tester, _display('24'), reduceMotion: true);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byType(FadeTransition), findsWidgets);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_visible(tester), '€0,24');
  });

  testWidgets('fixed: full balance in fg.primary with a caption', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      _display(
        '3250',
        state: AmountDisplayState.fixed,
        message: 'Only the full balance can be redeemed here.',
      ),
    );
    expect(_visible(tester), '€32,50');
    expect(
      find.text(
        'Only the full balance can be redeemed here.',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('de-DE puts the symbol after the number', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      const AmountDisplay(
        digits: '2490',
        money: MoneyContext(
          currency: 'EUR',
          language: UiLanguage.de,
          restaurantLocale: RestaurantLocale.deDE,
        ),
      ),
      locale: const Locale('de'),
    );
    expect(_visible(tester), '24,90€');
  });
}
