import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import 'harness.dart';

void main() {
  setUpAll(loadWaiterFonts);

  group('PrimaryButton', () {
    for (final Brightness b in bothThemes) {
      testWidgets('large is 64 pt and full width in $b', (
        WidgetTester tester,
      ) async {
        await pumpComponent(
          tester,
          PrimaryButton(label: 'Scan card', onPressed: () {}),
          brightness: b,
        );
        final Size size = tester.getSize(find.byType(PrimaryButton));
        expect(size.height, 64);
        expect(size.width, 390 - 40);
      });
    }

    testWidgets('large is 56 pt at compact height; regular is 56 pt', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        PrimaryButton(label: 'Scan card', onPressed: () {}),
        size: const Size(375, 667),
      );
      expect(tester.getSize(find.byType(PrimaryButton)).height, 56);
      await pumpComponent(
        tester,
        PrimaryButton(
          label: 'Sign in',
          size: ButtonSize.regular,
          onPressed: () {},
        ),
      );
      expect(tester.getSize(find.byType(PrimaryButton)).height, 56);
    });

    testWidgets('activates on touch-up inside; a move out cancels', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpComponent(
        tester,
        PrimaryButton(label: 'Scan card', onPressed: () => taps++),
      );
      await tester.tap(find.byType(PrimaryButton));
      expect(taps, 1);

      final Rect rect = tester.getRect(find.byType(PrimaryButton));
      final TestGesture g = await tester.startGesture(rect.center);
      await tester.pump();
      expect(taps, 1, reason: 'not on touch-down');
      await g.moveTo(Offset(rect.center.dx, rect.bottom + 20));
      await g.up();
      await tester.pump();
      expect(taps, 1, reason: 'moved more than 16 pt outside');
    });

    testWidgets('semantics: label, disabled hint', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const PrimaryButton(
          label: 'Redeem € 24,90',
          semanticLabel: 'Redeem 24 euros 90',
          disabledReason: 'Enter amount',
          onPressed: null,
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(PrimaryButton),
      );
      expect(node.label, 'Redeem 24 euros 90');
      expect(node.hint, 'Enter amount');
      expect(node, isSemantics(isButton: true, isEnabled: false));
      handle.dispose();
    });

    testWidgets('loading: no spinner before 150 ms, spinner after', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpComponent(
        tester,
        PrimaryButton(
          label: 'Sign in',
          onPressed: () => taps++,
          status: ButtonStatus.loading,
        ),
      );
      expect(find.byType(Spinner), findsNothing);
      await tester.pump(const Duration(milliseconds: 149));
      expect(find.byType(Spinner), findsNothing);
      await tester.pump(const Duration(milliseconds: 2));
      expect(find.byType(Spinner), findsOneWidget);
      await tester.tap(find.byType(PrimaryButton));
      expect(taps, 0, reason: 'inert while loading');
      expect(
        tester.getSize(find.byType(PrimaryButton)).height,
        64,
        reason: 'size never changes',
      );
    });

    testWidgets('an amount label breaks at " · " when it does not fit', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        PrimaryButton(label: 'Redeem full balance · € 32,50', onPressed: () {}),
        textScale: 2,
      );
      final RichText text = tester.widget<RichText>(
        find.descendant(
          of: find.byType(ButtonLabel),
          matching: find.byType(RichText),
        ),
      );
      expect(text.text.toPlainText(), 'Redeem full balance\n€ 32,50');
      expect(tester.takeException(), isNull);
    });
  });

  group('Secondary, Tertiary, Danger', () {
    for (final Brightness b in bothThemes) {
      testWidgets('meet the 56-pt target in $b', (WidgetTester tester) async {
        await pumpComponent(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SecondaryButton(label: 'QR code', onPressed: () {}),
              TertiaryButton(label: 'Not now', onPressed: () {}),
              DangerButton(label: 'Sign out', onPressed: () {}),
            ],
          ),
          brightness: b,
        );
        for (final Type t in <Type>[
          SecondaryButton,
          TertiaryButton,
          DangerButton,
        ]) {
          final Size s = tester.getSize(find.byType(t));
          expect(s.height, Sizes.targetMin, reason: '$t');
          expect(s.width, greaterThanOrEqualTo(120), reason: '$t');
        }
      });
    }

    testWidgets('TertiaryButton can be a link', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        TertiaryButton(
          label: 'Forgot password',
          isLink: true,
          onPressed: () {},
        ),
      );
      final SemanticsNode node = tester.getSemantics(
        find.byType(TertiaryButton),
      );
      expect(node, isSemantics(isLink: true));
      expect(node.label, 'Forgot password');
      handle.dispose();
    });
  });

  group('WaiterIconButton', () {
    testWidgets('56 target, toggle semantics, icon swap', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      bool on = false;
      await pumpComponent(
        tester,
        StatefulBuilder(
          builder: (BuildContext context, StateSetter set) => WaiterIconButton(
            icon: WaiterIcon.flashlight,
            toggledIcon: WaiterIcon.flashlightOff,
            semanticLabel: 'Turn on light',
            toggled: on,
            variant: IconButtonVariant.onCamera,
            onPressed: () => set(() => on = !on),
          ),
        ),
      );
      expect(tester.getSize(find.byType(WaiterIconButton)), const Size(56, 56));
      SemanticsNode node = tester.getSemantics(find.byType(WaiterIconButton));
      expect(node, isSemantics(hasToggledState: true, isToggled: false));
      await tester.tap(find.byType(WaiterIconButton));
      await tester.pump();
      node = tester.getSemantics(find.byType(WaiterIconButton));
      expect(node, isSemantics(hasToggledState: true, isToggled: true));
      final WaiterIconView icon = tester.widget(find.byType(WaiterIconView));
      expect(icon.icon, WaiterIcon.flashlightOff);
      handle.dispose();
    });
  });
}
