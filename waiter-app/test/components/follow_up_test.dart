import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/api/models.dart' show VoucherStatus;
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import 'harness.dart';

/// Records screen-reader announcements.
List<String> _announcements(WidgetTester tester) {
  final List<String> said = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (Object? message) async {
      final Map<Object?, Object?> m = message! as Map<Object?, Object?>;
      final Map<Object?, Object?> data = m['data']! as Map<Object?, Object?>;
      said.add(data['message']! as String);
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
  return said;
}

void main() {
  setUpAll(loadWaiterFonts);

  group('WaiterTextField', () {
    late TextEditingController controller;
    setUp(() => controller = TextEditingController());
    tearDown(() => controller.dispose());

    Widget field({String? error, bool readOnly = false}) => WaiterTextField(
      kind: TextFieldKind.password,
      label: 'Password',
      controller: controller,
      errorText: error,
      readOnly: readOnly,
    );

    testWidgets('an error toggling on/off/on within 160 ms is fine', (
      WidgetTester tester,
    ) async {
      await pumpComponent(tester, field());
      await pumpComponent(tester, field(error: 'Required'));
      await tester.pump(const Duration(milliseconds: 40));
      await pumpComponent(tester, field());
      await tester.pump(const Duration(milliseconds: 40));
      await pumpComponent(tester, field(error: 'Required'));
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Required', findRichText: true), findsOneWidget);
    });

    testWidgets('read-only: not editable, keeps the resting look', (
      WidgetTester tester,
    ) async {
      await pumpComponent(tester, field(readOnly: true));
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, true);
      final AnimatedContainer box = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(WaiterTextField),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final BoxDecoration d = box.decoration! as BoxDecoration;
      expect(d.color, WaiterColors.light.bgSurface);
    });
  });

  group('PrimaryButton', () {
    testWidgets('loading label beside the spinner after 150 ms', (
      WidgetTester tester,
    ) async {
      final FocusNode focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpComponent(
        tester,
        PrimaryButton(
          label: 'Redeem € 24,90',
          loadingLabel: 'Redeeming € 24,90 …',
          status: ButtonStatus.loading,
          focusNode: focus,
          onPressed: () {},
        ),
      );
      await tester.pump(const Duration(milliseconds: 151));
      expect(find.byType(Spinner), findsOneWidget);
      expect(
        find.text('Redeeming € 24,90 …', findRichText: true),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(PrimaryButton)).height, 64);
      expect(focus.canRequestFocus, isFalse, reason: 'inert while loading');
    });
  });

  group('StatusBanner', () {
    testWidgets('ticking text is not re-announced; a tone change is', (
      WidgetTester tester,
    ) async {
      final List<String> said = _announcements(tester);
      Widget banner(BannerTone tone, String body) => StatusBanner(
        tone: tone,
        title: 'Limit for this card reached',
        body: body,
        announceTextChanges: false,
      );
      await pumpComponent(tester, banner(BannerTone.warning, 'In 0:42'));
      await tester.pump();
      await pumpComponent(tester, banner(BannerTone.warning, 'In 0:41'));
      await pumpComponent(tester, banner(BannerTone.warning, 'In 0:40'));
      expect(said, hasLength(1));
      await pumpComponent(tester, banner(BannerTone.info, 'In 0:39'));
      expect(said, hasLength(2));
    });
  });

  group('WaiterBanner', () {
    testWidgets('dismiss ✕ and a 2-line cap with the full text in a11y', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      int dismissed = 0;
      final String notice = List<String>.filled(20, 'Maintenance').join(' ');
      await pumpComponent(
        tester,
        WaiterBanner(
          tone: BannerTone.warning,
          icon: WaiterIcon.wrench,
          title: notice,
          maxLines: 2,
          onDismiss: () => dismissed++,
        ),
        center: false,
        reduceMotion: true,
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.bySemanticsLabel(notice), findsOneWidget);
      final RichText title = tester.widget<RichText>(
        find.text(notice, findRichText: true),
      );
      expect(title.maxLines, 2);
      final Finder close = find.bySemanticsLabel('Dismiss notice');
      expect(tester.getSize(close), const Size(56, 56));
      await tester.tap(close);
      expect(dismissed, 1);
      handle.dispose();
    });
  });

  group('Snackbar', () {
    Widget host(SnackbarData Function() data) => SnackbarHost(
      child: Builder(
        builder: (BuildContext c) => Center(
          child: SecondaryButton(
            label: 'Open',
            fullWidth: false,
            onPressed: () => SnackbarHost.of(c).show(data()),
          ),
        ),
      ),
    );

    testWidgets('own duration; onDismissed on timeout', (
      WidgetTester tester,
    ) async {
      int dismissed = 0;
      await pumpComponent(
        tester,
        host(
          () => SnackbarData(
            message: 'Connected again',
            duration: const Duration(seconds: 2),
            onDismissed: () => dismissed++,
          ),
        ),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1900));
      expect(dismissed, 0);
      await tester.pump(const Duration(milliseconds: 150));
      expect(dismissed, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Connected again', findRichText: true), findsNothing);
    });

    testWidgets('the action does not call onDismissed', (
      WidgetTester tester,
    ) async {
      int dismissed = 0;
      int switched = 0;
      await pumpComponent(
        tester,
        host(
          () => SnackbarData(
            message: 'Different card detected – Switch?',
            actionLabel: 'Switch',
            onAction: () => switched++,
            onDismissed: () => dismissed++,
          ),
        ),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Switch', findRichText: true));
      await tester.pump(const Duration(seconds: 5));
      expect(switched, 1);
      expect(dismissed, 0);
    });
  });

  testWidgets('TopBar.task: ✕ stays, dimmed and disabled while locked', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const Align(
        alignment: Alignment.topCenter,
        child: TopBar.task(onClose: null, closeLabel: 'Close card'),
      ),
      center: false,
    );
    final Finder close = find.bySemanticsLabel('Close card');
    expect(close, findsOneWidget);
    expect(tester.getSemantics(close), isSemantics(isEnabled: false));
    expect(
      tester.widget<WaiterIconView>(find.byType(WaiterIconView)).color,
      WaiterColors.light.fgTertiary,
    );
    handle.dispose();
  });

  group('AmountDisplay', () {
    testWidgets('balance changed: no shake and no warning haptic', (
      WidgetTester tester,
    ) async {
      final FeedbackRecorder feedback = FeedbackRecorder();
      addTearDown(feedback.dispose);
      Widget display(AmountDisplayState state) => AmountDisplay(
        digits: '2490',
        money: testMoney,
        state: state,
        overBalanceEntryFeedback: false,
      );
      await pumpComponent(
        tester,
        display(AmountDisplayState.entering),
        feedback: feedback.service,
      );
      await pumpComponent(
        tester,
        display(AmountDisplayState.overBalance),
        feedback: feedback.service,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      expect(feedback.haptics, isEmpty);
      final Transform t = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(AmountDisplay),
              matching: find.byType(Transform),
            )
            .first,
      );
      expect(t.transform.getTranslation().x, 0);
    });

    testWidgets('message and chip are reachable by screen readers', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        AmountDisplay(
          digits: '4000',
          money: testMoney,
          state: AmountDisplayState.overBalance,
          message: '€ 7,50 more than the balance',
          chip: QuickAmountChip(
            cents: 3250,
            money: testMoney,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.bySemanticsLabel('€ 7,50 more than the balance'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Use balance, 32 euros 50')),
        isSemantics(isButton: true),
      );
      expect(find.bySemanticsLabel('Amount 40 euros'), findsOneWidget);
      handle.dispose();
    });
  });

  group('BalanceCard sizing', () {
    const BalanceCardData data = BalanceCardData(
      restaurantName: 'Zum Hirschen',
      balanceCents: 3250,
      last4: '6488',
      status: VoucherStatus.active,
    );

    testWidgets('ratio kept inside a lower max height, centred', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        const BalanceCard(data: data, money: testMoney, maxHeight: 150),
      );
      final Size card = tester.getSize(
        find
            .descendant(
              of: find.byType(BalanceCard),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(card.height, 150);
      expect(card.width, closeTo(150 * 1.586, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tablet cap 277 pt', (WidgetTester tester) async {
      await pumpComponent(
        tester,
        const SizedBox(
          width: 440,
          child: BalanceCard(data: data, money: testMoney, maxHeight: 277),
        ),
        size: const Size(820, 1180),
      );
      expect(tester.getSize(find.byType(BalanceCard)).height, 277);
    });

    testWidgets('no keypad: full card even at compact window height', (
      WidgetTester tester,
    ) async {
      late BalanceCardDensity withKeypad;
      late BalanceCardDensity fullOnly;
      await pumpComponent(
        tester,
        Builder(
          builder: (BuildContext context) {
            withKeypad = BalanceCardDensity.choose(
              context,
              availableHeight: 200,
            );
            fullOnly = BalanceCardDensity.choose(
              context,
              availableHeight: 200,
              withKeypad: false,
            );
            return const SizedBox();
          },
        ),
        size: const Size(375, 667),
      );
      expect(withKeypad, BalanceCardDensity.compact);
      expect(fullOnly, BalanceCardDensity.full);
    });
  });

  testWidgets('Keypad: 80-pt keys in the tall tablet two-pane', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      Keypad(
        onDigit: (_) => EntryOutcome.accepted,
        onDoubleZero: () => EntryOutcome.accepted,
        onBackspace: () => EntryOutcome.deleted,
        onClear: () => EntryOutcome.cleared,
      ),
      size: const Size(1180, 820),
    );
    expect(tester.getSize(find.bySemanticsLabel('5')).height, 80);
    handle.dispose();
  });

  testWidgets('ProblemScreen throttled: ill_wait, ring below, caption', (
    WidgetTester tester,
  ) async {
    final List<String> said = _announcements(tester);
    Widget screen(String? caption) => ProblemScreen(
      family: ProblemFamily.throttled,
      title: 'Too many scans',
      body: 'Scanning is possible again shortly.',
      primary: const ProblemAction('Scan again · 0:12', null),
      countdown: const ProblemCountdown(
        remaining: Duration(seconds: 12),
        total: Duration(seconds: 30),
      ),
      caption: caption,
    );
    await pumpComponent(tester, screen(null), center: false);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(IllustrationView), findsOneWidget);
    expect(find.byType(ProgressRing), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(ProgressRing)).dy,
      greaterThan(
        tester
            .getTopLeft(
              find.text(
                'Scanning is possible again shortly.',
                findRichText: true,
              ),
            )
            .dy,
      ),
    );
    await pumpComponent(tester, screen('No connection'), center: false);
    await tester.pump();
    expect(find.text('No connection', findRichText: true), findsOneWidget);
    expect(said, contains('No connection'));
  });

  testWidgets('Avatar 72 pt', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      const Avatar(name: 'Lukas Gruber', size: AvatarSize.extraLarge),
    );
    expect(tester.getSize(find.byType(Avatar)), const Size(72, 72));
    expect(find.text('LG', findRichText: true), findsOneWidget);
  });

  group('showWaiterScrollSheet', () {
    Widget host({String? barrierLabel}) => Builder(
      builder: (BuildContext c) => Center(
        child: SecondaryButton(
          label: 'Open',
          fullWidth: false,
          onPressed: () => showWaiterScrollSheet<void>(
            context: c,
            title: 'Recent',
            barrierLabel: barrierLabel,
            builder: (BuildContext _, ScrollController controller) =>
                ListView.builder(
                  controller: controller,
                  itemCount: 40,
                  itemBuilder: (BuildContext _, int i) =>
                      SizedBox(height: 64, child: Text('Row $i')),
                ),
          ),
        ),
      ),
    );

    testWidgets('opens at the large detent on compact height', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        host(),
        size: const Size(375, 667),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.byType(WaiterBottomSheet)).dy,
        closeTo(SheetTokens.largeTopGap, 1),
      );
    });

    testWidgets('custom scrim label', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await pumpComponent(
        tester,
        host(barrierLabel: 'Close menu'),
        center: false,
      );
      await tester.tap(find.text('Open', findRichText: true));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Close menu'), findsOneWidget);
      handle.dispose();
    });
  });
}
