import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import 'harness.dart';

void main() {
  setUpAll(loadWaiterFonts);

  group('ProblemScreen', () {
    Widget screen({VoidCallback? onClose}) => SnackbarHost(
      child: ProblemScreen(
        family: ProblemFamily.notFound,
        title: 'Card not found',
        body: 'This card is not in the system.',
        primary: ProblemAction('Scan again', () {}),
        tertiary: ProblemAction('Enter card number', () {}),
        onClose: onClose,
        supportCode: '7F3A9C',
        requestId: '5e1c8f3a-7d2b-4b1e-9c7f-4b1e9c7f3a9c',
      ),
    );

    for (final Brightness b in bothThemes) {
      testWidgets('title header, actions, error feedback ($b)', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        final FeedbackRecorder feedback = FeedbackRecorder();
        addTearDown(feedback.dispose);
        await pumpComponent(
          tester,
          screen(onClose: () {}),
          brightness: b,
          feedback: feedback.service,
          center: false,
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.getSemantics(find.bySemanticsLabel('Card not found')),
          isSemantics(isHeader: true),
        );
        expect(find.byType(PrimaryButton), findsOneWidget);
        expect(find.byType(TertiaryButton), findsOneWidget);
        expect(find.byType(TopBar), findsOneWidget);
        expect(feedback.haptics, <String>['REJECT'], reason: 'haptic.error');
        expect(
          find.bySemanticsLabel('Support code 7 F 3 A 9 C'),
          findsOneWidget,
        );
        handle.dispose();
      });
    }

    testWidgets('long-press on the code copies the request id', (
      WidgetTester tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
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
      await pumpComponent(tester, screen(), center: false);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.longPress(find.text('Code 7F3A9C', findRichText: true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(copied, '5e1c8f3a-7d2b-4b1e-9c7f-4b1e9c7f3a9c');
      expect(find.text('Copied', findRichText: true), findsOneWidget);
    });

    testWidgets('verification uses the calm warning tone', (
      WidgetTester tester,
    ) async {
      final FeedbackRecorder feedback = FeedbackRecorder();
      addTearDown(feedback.dispose);
      await pumpComponent(
        tester,
        ProblemScreen(
          family: ProblemFamily.server,
          visual: const ProblemVisual.icon(WaiterIcon.shieldAlert),
          title: 'Card could not be verified',
          body: 'Do not accept this card for now. Please get a manager.',
          primary: ProblemAction('Scan again', () {}),
        ),
        feedback: feedback.service,
        center: false,
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<WaiterIconView>(find.byType(WaiterIconView)).color,
        WaiterColors.resolve(Brightness.light).danger,
      );
      expect(
        ProblemFamily.verification.toneColor(WaiterColors.light),
        WaiterColors.light.warning,
      );
      expect(ProblemFamily.verification.haptic, HapticToken.error);
      expect(ProblemFamily.throttled.haptic, HapticToken.warning);
      expect(feedback.haptics, <String>['waveform'], reason: 'server: warning');
    });

    testWidgets('countdown visual; no stagger under Reduce Motion', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const ProblemScreen(
          family: ProblemFamily.throttled,
          visual: ProblemVisual.countdown(
            remaining: Duration(seconds: 12),
            total: Duration(seconds: 30),
          ),
          title: 'Too many scans',
          body: 'Scanning is possible again shortly.',
          primary: ProblemAction('Scan again · 0:12', null),
        ),
        reduceMotion: true,
        center: false,
      );
      await tester.pump();
      expect(find.byType(ProgressRing), findsOneWidget);
      final Opacity title = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Too many scans', findRichText: true),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(title.opacity, 1);
    });
  });

  group('TopBar and Avatar', () {
    for (final Brightness b in bothThemes) {
      testWidgets('home: 56 pt, avatar, two 56-pt buttons ($b)', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await pumpComponent(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: TopBar.home(
              restaurantName: 'Zum Hirschen',
              userName: 'Maria Koller',
              onRecent: () {},
              onMenu: () {},
            ),
          ),
          brightness: b,
          center: false,
        );
        expect(tester.getSize(find.byType(TopBar)).height, closeTo(57, 1));
        expect(find.text('MK', findRichText: true), findsOneWidget);
        expect(tester.getSize(find.byType(Avatar)), const Size(40, 40));
        expect(find.byType(WaiterIconButton), findsNWidgets(2));
        expect(find.bySemanticsLabel('Menu, Maria Koller'), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Zum Hirschen')),
          isSemantics(isHeader: true),
        );
        handle.dispose();
      });
    }

    testWidgets('task: ✕ and the card number read in groups', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        TopBar.task(
          onClose: () {},
          closeLabel: 'Close card',
          cardNumber: '5285105870986488',
        ),
        center: false,
      );
      expect(find.bySemanticsLabel('Close card'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Card number 5 2 8 5, 1 0 5 8, 7 0 9 8, 6 4 8 8'),
        findsOneWidget,
      );
      handle.dispose();
    });

    test('initials: given + family name, digraphs, fallbacks', () {
      expect(avatarInitials('Maria Koller'), 'MK');
      expect(avatarInitials('Anna'), 'A');
      expect(avatarInitials('Ljubica Njegoš'), 'Lj');
      expect(avatarInitials('Ljubica Horvat'), 'LjH');
      expect(avatarInitials('Džana Begić'), 'DžB');
      expect(avatarInitials('  '), isNull);
      expect(avatarInitials('Ивана Петровић'), isNull);
      expect(avatarInitials('Jan Maria van der Berg'), 'JB');
    });

    testWidgets('user icon when there are no Latin initials', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const Avatar(name: 'Ивана', size: AvatarSize.large),
      );
      expect(tester.getSize(find.byType(Avatar)), const Size(56, 56));
      expect(
        tester.widget<WaiterIconView>(find.byType(WaiterIconView)).icon,
        WaiterIcon.user,
      );
    });
  });

  group('Recent', () {
    for (final Brightness b in bothThemes) {
      testWidgets('TransactionRow: ≥ 64 pt, one button element ($b)', (
        WidgetTester tester,
      ) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        int taps = 0;
        await pumpComponent(
          tester,
          TransactionRow(
            time: WallTime(14, 32),
            last4: '6488',
            amountCents: 2490,
            remainingCents: 760,
            money: testMoney,
            onPressed: () => taps++,
          ),
          brightness: b,
          center: false,
        );
        expect(
          tester.getSize(find.byType(TransactionRow)).height,
          greaterThanOrEqualTo(64),
        );
        final Finder row = find.bySemanticsLabel(
          '14:32, card ending 6 4 8 8, 24 euros 90 redeemed, '
          'remaining balance 7 euros 60',
        );
        expect(row, findsOneWidget);
        expect(tester.getSemantics(row), isSemantics(isButton: true));
        await tester.tap(find.byType(TransactionRow));
        expect(taps, 1);
        handle.dispose();
      });
    }

    testWidgets('HistoryCard: total, count and spoken summary', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const HistoryCard(
          count: 12,
          totalCents: 48640,
          money: testMoney,
          limitReached: true,
        ),
      );
      expect(find.text('€ 486,40', findRichText: true), findsOneWidget);
      expect(
        find.text(
          '12 redemptions · Latest 200 redemptions',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('12 redemptions, 486 euros 40 today'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('EmptyState: title and body, optional action', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        EmptyState(
          illustration: WaiterIllustration.recentEmpty,
          title: 'No redemptions yet',
          body: 'Redemptions from this phone appear here until 04:00.',
          actionLabel: 'Close',
          onAction: () {},
        ),
      );
      expect(find.byType(IllustrationView), findsOneWidget);
      expect(find.byType(SecondaryButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
