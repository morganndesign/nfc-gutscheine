import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import 'harness.dart';

/// The border side of the field container below [of].
BorderSide _border(WidgetTester tester, Finder of) {
  final AnimatedContainer box = tester.widget<AnimatedContainer>(
    find.descendant(of: of, matching: find.byType(AnimatedContainer)).first,
  );
  final BoxDecoration d = box.decoration! as BoxDecoration;
  return (d.border! as Border).top;
}

/// Horizontal translation of the shake wrapper below [of].
double _shakeX(WidgetTester tester, Finder of) {
  final Transform t = tester.widget<Transform>(
    find.descendant(of: of, matching: find.byType(Transform)).first,
  );
  return t.transform.getTranslation().x;
}

void main() {
  setUpAll(loadWaiterFonts);

  group('WaiterTextField', () {
    late TextEditingController controller;
    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    for (final Brightness b in bothThemes) {
      testWidgets('56-pt container, border.control at rest ($b)', (
        WidgetTester tester,
      ) async {
        await pumpComponent(
          tester,
          WaiterTextField(
            kind: TextFieldKind.email,
            label: 'E-mail',
            controller: controller,
          ),
          brightness: b,
        );
        final WaiterColors c = WaiterColors.resolve(b);
        final BorderSide side = _border(tester, find.byType(WaiterTextField));
        expect(side.color, c.borderControl);
        expect(side.width, 1);
        expect(
          tester
              .getSize(
                find
                    .descendant(
                      of: find.byType(WaiterTextField),
                      matching: find.byType(AnimatedContainer),
                    )
                    .first,
              )
              .height,
          greaterThanOrEqualTo(56),
        );
      });
    }

    testWidgets('focus ring on focus, danger on error', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        WaiterTextField(
          kind: TextFieldKind.email,
          label: 'E-mail',
          controller: controller,
        ),
      );
      await tester.tap(find.byType(TextField));
      await tester.pump(const Duration(milliseconds: 200));
      final WaiterColors c = WaiterColors.resolve(Brightness.light);
      BorderSide side = _border(tester, find.byType(WaiterTextField));
      expect(side.color, c.focusRing);
      expect(side.width, 2);
      await pumpComponent(
        tester,
        WaiterTextField(
          kind: TextFieldKind.email,
          label: 'E-mail',
          controller: controller,
          errorText: 'Check the e-mail address',
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      side = _border(tester, find.byType(WaiterTextField));
      expect(side.color, c.danger);
      expect(
        find.text('Check the e-mail address', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('error shake: 240 ms, ±6 pt; none under Reduce Motion', (
      WidgetTester tester,
    ) async {
      final ShakeController shake = ShakeController();
      addTearDown(shake.dispose);
      Widget field() => WaiterTextField(
        kind: TextFieldKind.password,
        label: 'Password',
        controller: controller,
        errorText: 'E-mail or password is incorrect.',
        shakeController: shake,
      );
      await pumpComponent(tester, field());
      final Finder root = find.byType(WaiterTextField);
      shake.shake();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(_shakeX(tester, root), closeTo(6, 0.01));
      await tester.pump(const Duration(milliseconds: 60));
      expect(_shakeX(tester, root), closeTo(-6, 0.01));
      await tester.pump(const Duration(milliseconds: 150));
      expect(_shakeX(tester, root), 0);

      await pumpComponent(tester, field(), reduceMotion: true);
      shake.shake();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(_shakeX(tester, root), 0);
    });

    testWidgets('password toggle: 56 target, toggle semantics', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        WaiterTextField(
          kind: TextFieldKind.password,
          label: 'Password',
          controller: controller,
        ),
      );
      final Finder toggle = find.byType(WaiterIconButton);
      expect(tester.getSize(toggle), const Size(56, 56));
      expect(
        tester.getSemantics(toggle),
        isSemantics(
          label: 'Show password',
          hasToggledState: true,
          isToggled: false,
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        true,
      );
      await tester.tap(toggle);
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).obscureText,
        false,
      );
      expect(
        tester.getSemantics(toggle),
        isSemantics(hasToggledState: true, isToggled: true),
      );
      handle.dispose();
    });
  });

  group('CardNumberField', () {
    for (final Brightness b in bothThemes) {
      testWidgets('64 pt, groups of four, empty cells "·" ($b)', (
        WidgetTester tester,
      ) async {
        await pumpComponent(
          tester,
          const CardNumberField(digits: '5285105870'),
          brightness: b,
        );
        await tester.pump(const Duration(milliseconds: 100));
        final Iterable<String> cells = tester
            .widgetList<RichText>(
              find.descendant(
                of: find.byType(CardNumberField),
                matching: find.byType(RichText),
              ),
            )
            .map((RichText t) => t.text.toPlainText());
        expect(cells.where((String c) => c == '·'), hasLength(6));
        expect(
          tester
              .getSize(
                find
                    .descendant(
                      of: find.byType(CardNumberField),
                      matching: find.byType(AnimatedContainer),
                    )
                    .first,
              )
              .height,
          64,
        );
        expect(
          _border(tester, find.byType(CardNumberField)).color,
          WaiterColors.resolve(b).focusRing,
        );
      });
    }

    testWidgets('reads in groups; label and hint', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpComponent(tester, const CardNumberField(digits: '5285105870'));
      expect(find.bySemanticsLabel('Card number'), findsOneWidget);
      final SemanticsNode node = tester.getSemantics(
        find.bySemanticsLabel('Card number'),
      );
      expect(node.value, '5 2 8 5, 1 0 5 8, 7 0');
      expect(node, isSemantics(isTextField: true, isReadOnly: true));
      handle.dispose();
    });

    testWidgets('fits a 320-pt phone at 200 % without overflow', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const CardNumberField(digits: '5285105870986488'),
        textScale: 2,
        size: const Size(320, 568),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('error border and message', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        const CardNumberField(
          digits: '5285105870986488',
          errorText: 'Check the card number',
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        _border(tester, find.byType(CardNumberField)).color,
        WaiterColors.resolve(Brightness.light).danger,
      );
      expect(
        find.text('Check the card number', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('QuickAmountChip', () {
    testWidgets('40 visual / 56 target, spoken label, haptic.select', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final FeedbackRecorder feedback = FeedbackRecorder();
      addTearDown(feedback.dispose);
      int taps = 0;
      await pumpComponent(
        tester,
        QuickAmountChip(cents: 3250, money: testMoney, onPressed: () => taps++),
        feedback: feedback.service,
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        find.text('Use balance · €\u00A032,50', findRichText: true),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(QuickAmountChip)).height, 56);
      expect(find.bySemanticsLabel('Use balance, 32 euros 50'), findsOneWidget);
      await tester.tap(find.byType(QuickAmountChip));
      expect(taps, 1);
      expect(feedback.haptics, <String>['CLOCK_TICK']);
      handle.dispose();
    });
  });
}
