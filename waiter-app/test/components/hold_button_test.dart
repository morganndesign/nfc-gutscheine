import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/hold_button.dart';

import 'harness.dart';

void main() {
  late FeedbackRecorder feedback;
  late int commits;

  setUpAll(loadWaiterFonts);
  setUp(() {
    feedback = FeedbackRecorder();
    commits = 0;
  });
  tearDown(() => feedback.dispose());

  Widget button({VoidCallback? onCommit, bool enabled = true}) => HoldButton(
    label: 'Redeem € 124,90',
    semanticLabel: 'Redeem 124 euros 90',
    redeemingCaption: 'Redeeming € 124,90 …',
    onCommit: enabled ? (onCommit ?? () => commits++) : null,
  );

  for (final Brightness b in bothThemes) {
    testWidgets('renders in $b at 64 pt and full width', (
      WidgetTester tester,
    ) async {
      await pumpComponent(tester, button(), brightness: b);
      final Size size = tester.getSize(find.byType(HoldButton));
      expect(size.height, greaterThanOrEqualTo(64));
      expect(size.width, 390 - 40);
      expect(find.text('Hold to redeem', findRichText: true), findsOneWidget);
    });
  }

  testWidgets('599 ms does not commit, 600 ms commits with three ticks', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, button(), feedback: feedback.service);
    final TestGesture g = await tester.startGesture(
      tester.getCenter(find.byType(HoldButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 199));
    expect(feedback.haptics, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(feedback.haptics, <String>['CLOCK_TICK']);
    await tester.pump(const Duration(milliseconds: 200));
    expect(feedback.haptics, <String>['CLOCK_TICK', 'CLOCK_TICK']);
    await tester.pump(const Duration(milliseconds: 199));
    expect(commits, 0, reason: '599 ms is not enough');
    await tester.pump(const Duration(milliseconds: 1));
    expect(commits, 1);
    expect(feedback.haptics, <String>['CLOCK_TICK', 'CLOCK_TICK', 'CONFIRM']);
    // Step indices 0/1/2 select the 0.5 / 0.7 / 1.0 intensities.
    await g.up();
    await tester.pump(const Duration(seconds: 1));
    expect(commits, 1, reason: 'release after commit does nothing');
  });

  testWidgets('release before 600 ms cancels and drains the ring', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, button(), feedback: feedback.service);
    final TestGesture g = await tester.startGesture(
      tester.getCenter(find.byType(HoldButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await g.up();
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump(const Duration(seconds: 1));
    expect(commits, 0);
    expect(feedback.haptics, <String>['CLOCK_TICK', 'CLOCK_TICK']);
  });

  testWidgets('sliding more than 12 pt outside cancels', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, button());
    final Rect rect = tester.getRect(find.byType(HoldButton));
    final TestGesture g = await tester.startGesture(rect.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await g.moveTo(Offset(rect.center.dx, rect.bottom + 13));
    await tester.pump(const Duration(milliseconds: 700));
    expect(commits, 0);
    await g.up();
  });

  testWidgets('a quick tap teaches: caption announced, no commit', (
    WidgetTester tester,
  ) async {
    final List<String> announcements = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
      SystemChannels.accessibility,
      (Object? message) async {
        final Map<Object?, Object?> m = message! as Map<Object?, Object?>;
        final Map<Object?, Object?> data = m['data']! as Map<Object?, Object?>;
        announcements.add(data['message']! as String);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger
          .setMockDecodedMessageHandler<Object?>(
            SystemChannels.accessibility,
            null,
          ),
    );
    await pumpComponent(tester, button());
    await tester.tap(find.byType(HoldButton));
    await tester.pump(const Duration(milliseconds: 300));
    expect(commits, 0);
    expect(announcements, contains('Hold to redeem'));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('accessible paths: arm then confirm; custom action; long press', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(tester, button(), feedback: feedback.service);
    final SemanticsNode node = tester.getSemantics(find.byType(HoldButton));
    expect(node.label, 'Redeem 124 euros 90');
    expect(node.value, 'Hold to redeem');
    expect(node.hint, isNotEmpty);
    final SemanticsOwner owner = node.owner!;

    // Path B: first activation arms (haptic.select), the second commits.
    owner.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(commits, 0);
    expect(feedback.haptics, <String>['CLOCK_TICK']);
    owner.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(commits, 1);

    // Path B timeout: an arm expires after 10 s without a request.
    await pumpComponent(tester, const SizedBox());
    await pumpComponent(tester, button(), feedback: feedback.service);
    final SemanticsNode fresh = tester.getSemantics(find.byType(HoldButton));
    owner.performAction(fresh.id, SemanticsAction.tap);
    await tester.pump(HoldButton.armWindow + const Duration(seconds: 1));
    owner.performAction(fresh.id, SemanticsAction.tap);
    await tester.pump();
    expect(commits, 1, reason: 'the expired arm only re-arms');

    // Path A (TalkBack long press) and Path C (custom action) commit.
    owner.performAction(fresh.id, SemanticsAction.longPress);
    await tester.pump();
    expect(commits, 2);

    await pumpComponent(tester, const SizedBox());
    await pumpComponent(tester, button(), feedback: feedback.service);
    final SemanticsNode third = tester.getSemantics(find.byType(HoldButton));
    owner.performAction(
      third.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Redeem 124 euros 90'),
      ),
    );
    await tester.pump();
    expect(commits, 3);
    handle.dispose();
  });

  testWidgets('Reduce Motion keeps the ring (progress indicator)', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, button(), reduceMotion: true);
    final TestGesture g = await tester.startGesture(
      tester.getCenter(find.byType(HoldButton)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(commits, 1);
    await g.up();
  });

  testWidgets('disabled: no commit, hint is the reason', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const HoldButton(
        label: 'Redeem € 124,90',
        semanticLabel: 'Redeem 124 euros 90',
        redeemingCaption: 'Redeeming',
        onCommit: null,
        disabledReason: 'More than the balance',
      ),
    );
    expect(
      tester.getSemantics(find.byType(HoldButton)).hint,
      'More than the balance',
    );
    expect(find.text('Hold to redeem', findRichText: true), findsNothing);
    handle.dispose();
  });
}
