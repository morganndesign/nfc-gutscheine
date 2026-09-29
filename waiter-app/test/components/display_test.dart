import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import 'harness.dart';

/// Records screen-reader announcements.
List<String> _recordAnnouncements(WidgetTester tester) {
  final List<String> messages = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (Object? message) async {
      final Map<Object?, Object?> m = message! as Map<Object?, Object?>;
      final Map<Object?, Object?> data = m['data']! as Map<Object?, Object?>;
      messages.add(data['message']! as String);
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
  return messages;
}

void main() {
  setUpAll(loadWaiterFonts);

  group('StatusBadge', () {
    for (final Brightness b in bothThemes) {
      testWidgets('4 statuses, icon + text, 24 pt ($b)', (
        WidgetTester tester,
      ) async {
        await pumpComponent(
          tester,
          Wrap(
            children: <Widget>[
              for (final BadgeStatus s in BadgeStatus.values)
                StatusBadge(status: s),
            ],
          ),
          brightness: b,
        );
        for (final String label in <String>[
          'Active',
          'Used up',
          'Blocked',
          'Expired',
        ]) {
          expect(find.text(label, findRichText: true), findsOneWidget);
        }
        expect(find.byType(WaiterIconView), findsNWidgets(4));
        for (final Element e in find.byType(StatusBadge).evaluate()) {
          expect(tester.getSize(find.byWidget(e.widget)).height, 24);
        }
      });
    }

    testWidgets('high contrast adds a border in the text colour', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const StatusBadge(status: BadgeStatus.blocked),
        highContrast: true,
      );
      final Container box = tester.widget<Container>(
        find.descendant(
          of: find.byType(StatusBadge),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration d = box.decoration! as BoxDecoration;
      expect(d.border, isNotNull);
    });
  });

  group('StatusBanner', () {
    for (final Brightness b in bothThemes) {
      testWidgets('tones render with title, body and action ($b)', (
        WidgetTester tester,
      ) async {
        await pumpComponent(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final BannerTone t in BannerTone.values)
                StatusBanner(
                  tone: t,
                  title: 'Card blocked',
                  body: 'Please get a manager.',
                  actionLabel: t == BannerTone.danger ? 'Scan again' : null,
                  onAction: t == BannerTone.danger ? () {} : null,
                ),
            ],
          ),
          brightness: b,
          size: const Size(390, 1000),
        );
        expect(find.byType(StatusBanner), findsNWidgets(4));
        expect(find.byType(TertiaryButton), findsOneWidget);
        for (final Element e in find.byType(StatusBanner).evaluate()) {
          expect(
            tester.getSize(find.byWidget(e.widget)).height,
            greaterThanOrEqualTo(56),
          );
        }
      });
    }

    testWidgets('danger is announced assertively with haptic on appear', (
      WidgetTester tester,
    ) async {
      final List<String> said = _recordAnnouncements(tester);
      final FeedbackRecorder feedback = FeedbackRecorder();
      addTearDown(feedback.dispose);
      await pumpComponent(
        tester,
        const StatusBanner(
          tone: BannerTone.danger,
          title: 'Card blocked',
          body: 'Reason: Lost',
          icon: WaiterIcon.ban,
          appearHaptic: HapticToken.error,
          appearSound: SoundToken.error,
        ),
        feedback: feedback.service,
      );
      await tester.pump();
      expect(said, contains('Card blocked. Reason: Lost'));
      expect(feedback.haptics, <String>['REJECT']);
      expect(
        feedback.calls.where((MethodCall c) => c.method == 'sound'),
        hasLength(1),
      );
    });

    testWidgets('uncertain: spinner instead of the icon', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const StatusBanner(
          tone: BannerTone.warning,
          title: 'Connection interrupted',
          busy: true,
        ),
      );
      expect(find.byType(Spinner), findsOneWidget);
    });
  });

  group('indicators', () {
    for (final Brightness b in bothThemes) {
      testWidgets('Spinner 20/32 and ProgressRing 28/48 ($b)', (
        WidgetTester tester,
      ) async {
        await pumpComponent(
          tester,
          const Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Spinner(),
              Spinner(size: SpinnerSize.large),
              ProgressRing.hold(progress: 0.5),
              ProgressRing.countdown(
                remaining: Duration(seconds: 12),
                total: Duration(seconds: 30),
              ),
            ],
          ),
          brightness: b,
        );
        final List<Size> spinners = tester
            .widgetList(find.byType(Spinner))
            .map((Widget w) => tester.getSize(find.byWidget(w)))
            .toList();
        expect(spinners, <Size>[const Size(20, 20), const Size(32, 32)]);
        final List<Size> rings = tester
            .widgetList(find.byType(ProgressRing))
            .map((Widget w) => tester.getSize(find.byWidget(w)))
            .toList();
        expect(rings, <Size>[const Size(28, 28), const Size(48, 48)]);
        expect(find.text('12', findRichText: true), findsOneWidget);
      });
    }

    testWidgets('countdown ticks down, fades and announces at 0', (
      WidgetTester tester,
    ) async {
      final List<String> said = _recordAnnouncements(tester);
      int finished = 0;
      await pumpComponent(
        tester,
        ProgressRing.countdown(
          remaining: const Duration(seconds: 3),
          total: const Duration(seconds: 30),
          finishedAnnouncement: 'Scanning available again',
          onFinished: () => finished++,
        ),
      );
      expect(find.text('3', findRichText: true), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.text('2', findRichText: true), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 200));
      expect(finished, 1);
      expect(said, contains('Scanning available again'));
    });

    testWidgets('Skeleton: static at 60 % under Reduce Motion', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        SkeletonGroup(
          child: SkeletonBox.line(width: 160, type: TypeTokens.bodyL),
        ),
        reduceMotion: true,
      );
      expect(tester.getSize(find.byType(SkeletonBox)).height, 12);
      final Opacity o = tester.widget<Opacity>(
        find.descendant(
          of: find.byType(SkeletonGroup),
          matching: find.byType(Opacity),
        ),
      );
      expect(o.opacity, 0.6);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('SkeletonSwitcher appears after 150 ms, stays ≥ 240 ms', (
      WidgetTester tester,
    ) async {
      Widget host(bool loading) => SkeletonSwitcher(
        loading: loading,
        skeleton: const SkeletonGroup(
          child: SkeletonBox(width: 100, height: 20),
        ),
        child: const Text('content'),
      );
      await pumpComponent(tester, host(true));
      AnimatedOpacity opacity() => tester.widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(SkeletonSwitcher),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(opacity().opacity, 0);
      await tester.pump(const Duration(milliseconds: 151));
      expect(opacity().opacity, 1);
      await pumpComponent(tester, host(false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('content'), findsNothing, reason: 'min 240 ms');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('content'), findsOneWidget);
    });
  });

  group('SuccessMark', () {
    testWidgets('96 pt; success haptic + sound at t = 0', (
      WidgetTester tester,
    ) async {
      final FeedbackRecorder feedback = FeedbackRecorder();
      addTearDown(feedback.dispose);
      await pumpComponent(
        tester,
        const SuccessMark(),
        feedback: feedback.service,
      );
      expect(tester.getSize(find.byType(SuccessMark)), const Size(96, 96));
      expect(feedback.haptics, <String>['CONFIRM']);
      expect(
        feedback.calls
            .where((MethodCall c) => c.method == 'sound')
            .single
            .arguments,
        <String, Object?>{'file': 'gcw_success'},
      );
      await tester.pump(const Duration(milliseconds: 440));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse, reason: 'never loops');
    });

    testWidgets('Reduce Motion: fades in over 160 ms', (
      WidgetTester tester,
    ) async {
      await pumpComponent(tester, const SuccessMark(), reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 160));
      await tester.pump(const Duration(milliseconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('CountdownHairline', () {
    for (final Brightness b in bothThemes) {
      testWidgets('2 pt, full width, finishes after 4 s ($b)', (
        WidgetTester tester,
      ) async {
        int done = 0;
        await pumpComponent(
          tester,
          CountdownHairline(onFinished: () => done++),
          brightness: b,
        );
        expect(tester.getSize(find.byType(CountdownHairline)).height, 2);
        await tester.pump(const Duration(milliseconds: 3999));
        expect(done, 0);
        await tester.pump(const Duration(milliseconds: 2));
        expect(done, 1);
      });
    }

    testWidgets('pauses while paused, then resumes', (
      WidgetTester tester,
    ) async {
      int done = 0;
      await pumpComponent(tester, CountdownHairline(onFinished: () => done++));
      await tester.pump(const Duration(seconds: 2));
      await pumpComponent(
        tester,
        CountdownHairline(paused: true, onFinished: () => done++),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(done, 0);
      await pumpComponent(tester, CountdownHairline(onFinished: () => done++));
      await tester.pump(const Duration(milliseconds: 2100));
      expect(done, 1);
    });
  });
}
