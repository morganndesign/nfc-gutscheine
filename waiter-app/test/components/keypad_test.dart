import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import 'harness.dart';

/// A screen-like host applying the keypad to an [AmountEntry].
class _AmountHost extends StatefulWidget {
  const _AmountHost({this.enabled = true, this.autofocus = false});

  final bool enabled;
  final bool autofocus;

  @override
  State<_AmountHost> createState() => _AmountHostState();
}

class _AmountHostState extends State<_AmountHost> {
  AmountEntry entry = AmountEntry.empty;
  AmountEntry _beforeDelete = AmountEntry.empty;

  EntryOutcome _apply(EntryChange<AmountEntry> change) {
    setState(() => entry = change.value);
    return change.outcome;
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      ExcludeSemantics(child: Text(entry.digits, key: const Key('digits'))),
      Keypad(
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        onDigit: (int d) => _apply(entry.digit(d)),
        onDoubleZero: () => _apply(entry.doubleZero()),
        onBackspace: () {
          _beforeDelete = entry;
          return _apply(entry.backspace());
        },
        onClear: () => _apply(_beforeDelete.clear()),
      ),
    ],
  );
}

String _digits(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('digits'))).data!;

Finder _key(String label) => find.bySemanticsLabel(label);

void main() {
  late FeedbackRecorder feedback;

  setUpAll(loadWaiterFonts);
  setUp(() => feedback = FeedbackRecorder());
  tearDown(() => feedback.dispose());

  for (final Brightness b in bothThemes) {
    testWidgets('3 × 4 keys at 72 pt in $b', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpComponent(tester, const _AmountHost(), brightness: b);
      for (final String label in <String>[
        for (int i = 0; i <= 9; i++) '$i',
        'Double zero',
        'Delete',
      ]) {
        final Size size = tester.getSize(_key(label));
        expect(size.height, 72, reason: label);
        expect(size.width, greaterThanOrEqualTo(Sizes.targetMin));
      }
      expect(
        tester.getSemantics(_key('Delete')),
        isSemantics(isButton: true, isKeyboardKey: true),
      );
      expect(tester.getSemantics(_key('Delete')).hint, 'Long press to clear');
      handle.dispose();
    });
  }

  testWidgets('keys are 64 pt at compact height', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const _AmountHost(),
      size: const Size(375, 667),
    );
    expect(tester.getSize(_key('5')).height, 64);
    handle.dispose();
  });

  testWidgets('input registers on touch-down with haptic.key', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const _AmountHost(),
      feedback: feedback.service,
    );
    final TestGesture g = await tester.startGesture(
      tester.getCenter(_key('2')),
    );
    await tester.pump();
    expect(_digits(tester), '2', reason: 'before the finger lifts');
    expect(feedback.haptics, <String>['KEYBOARD_TAP']);
    await g.up();
    await tester.tap(_key('4'));
    await tester.tap(_key('9'));
    await tester.tap(_key('Double zero'));
    await tester.pump();
    expect(_digits(tester), '24900');
    handle.dispose();
  });

  testWidgets('leading zero is ignored silently', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const _AmountHost(),
      feedback: feedback.service,
    );
    await tester.tap(_key('0'));
    await tester.tap(_key('Double zero'));
    await tester.pump();
    expect(_digits(tester), '');
    expect(feedback.haptics, isEmpty);
    handle.dispose();
  });

  testWidgets('8th digit is rejected with haptic.warning', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const _AmountHost(),
      feedback: feedback.service,
    );
    for (final String d in <String>['1', '2', '3', '4', '5', '6', '7', '8']) {
      await tester.tap(_key(d));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(_digits(tester), '1234567');
    expect(feedback.haptics.last, 'waveform', reason: 'haptic.warning');
    handle.dispose();
  });

  testWidgets('long-press ⌫ for 500 ms clears with haptic.select', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const _AmountHost(),
      feedback: feedback.service,
    );
    for (final String d in <String>['2', '4', '9']) {
      await tester.tap(_key(d));
    }
    await tester.pump();
    feedback.calls.clear();
    final TestGesture g = await tester.startGesture(
      tester.getCenter(_key('Delete')),
    );
    await tester.pump();
    expect(_digits(tester), '24', reason: 'touch-down deletes one digit');
    await tester.pump(const Duration(milliseconds: 499));
    expect(_digits(tester), '24');
    await tester.pump(const Duration(milliseconds: 1));
    expect(_digits(tester), '');
    expect(feedback.haptics, <String>['KEYBOARD_TAP', 'CLOCK_TICK']);
    await g.up();
    await tester.pump();
    handle.dispose();
  });

  testWidgets('a short ⌫ tap deletes one digit only', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(tester, const _AmountHost());
    await tester.tap(_key('5'));
    await tester.tap(_key('6'));
    await tester.tap(_key('Delete'));
    await tester.pump(const Duration(seconds: 1));
    expect(_digits(tester), '5');
    handle.dispose();
  });

  testWidgets('disabled keypad ignores input', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(tester, const _AmountHost(enabled: false));
    await tester.tap(_key('5'), warnIfMissed: false);
    await tester.pump();
    expect(_digits(tester), '');
    handle.dispose();
  });

  testWidgets('hardware keyboard: digits, Backspace, Ctrl + Backspace', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, const _AmountHost(autofocus: true));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7);
    await tester.sendKeyEvent(LogicalKeyboardKey.numpad5);
    await tester.pump();
    expect(_digits(tester), '75');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(_digits(tester), '7');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(_digits(tester), '');
  });

  testWidgets('card-number variant has an empty bottom-left cell', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      Keypad(
        variant: KeypadVariant.cardNumber,
        onDigit: (_) => EntryOutcome.accepted,
        onBackspace: () => EntryOutcome.deleted,
        onClear: () => EntryOutcome.cleared,
      ),
    );
    expect(find.bySemanticsLabel('Double zero'), findsNothing);
    expect(find.bySemanticsLabel('Delete'), findsOneWidget);
    handle.dispose();
  });
}
