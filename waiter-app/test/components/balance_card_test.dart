import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/components/components.dart';
import 'package:giftcard_waiter/core/api/models.dart' show VoucherStatus;
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

import 'harness.dart';

BalanceCardData _card({
  VoucherStatus status = VoucherStatus.active,
  int balance = 3250,
  String? brand = '#7A1F2B',
  String last4 = '6488',
}) => BalanceCardData(
  restaurantName: 'Zum Hirschen',
  balanceCents: balance,
  last4: last4,
  status: status,
  expiresAt: CalendarDate(2029, 9, 26),
  brandColor: brand,
);

void main() {
  setUpAll(loadWaiterFonts);

  for (final Brightness b in bothThemes) {
    testWidgets('ID-1 ratio, capped at 220 pt, in $b', (
      WidgetTester tester,
    ) async {
      await pumpComponent(
        tester,
        BalanceCard(data: _card(), money: testMoney),
        brightness: b,
        size: const Size(375, 812),
      );
      Size size = tester.getSize(find.byType(BalanceCard));
      expect(size.width, 335);
      expect(size.height, closeTo(335 / 1.586, 0.01));
      await pumpComponent(
        tester,
        BalanceCard(data: _card(), money: testMoney),
        brightness: b,
        size: const Size(430, 932),
      );
      size = tester.getSize(find.byType(BalanceCard));
      expect(size.height, Sizes.balanceCardMaxHeight);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact strip is 88 pt', (WidgetTester tester) async {
    await pumpComponent(
      tester,
      BalanceCard(
        data: _card(status: VoucherStatus.blocked),
        money: testMoney,
        density: BalanceCardDensity.compact,
      ),
      size: const Size(375, 667),
      textScale: 1.3,
    );
    expect(tester.getSize(find.byType(BalanceCard)).height, 88);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('density: compact at compact height or 130 % text', (
    WidgetTester tester,
  ) async {
    late BalanceCardDensity regular;
    late BalanceCardDensity large;
    await pumpComponent(
      tester,
      Builder(
        builder: (BuildContext context) {
          regular = BalanceCardDensity.choose(context, availableHeight: 211);
          return const SizedBox();
        },
      ),
    );
    await pumpComponent(
      tester,
      Builder(
        builder: (BuildContext context) {
          large = BalanceCardDensity.choose(context, availableHeight: 211);
          return const SizedBox();
        },
      ),
      textScale: 1.3,
    );
    expect(regular, BalanceCardDensity.full);
    expect(large, BalanceCardDensity.compact);
  });

  testWidgets('one accessibility element with spoken balance and status', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      BalanceCard(
        data: _card(status: VoucherStatus.blocked),
        money: testMoney,
      ),
    );
    final SemanticsNode node = tester.getSemantics(find.byType(BalanceCard));
    expect(
      node.label,
      'Voucher Zum Hirschen. Balance 32 euros 50. Voucher ending 6 4 8 8. '
      'Valid until 26 September 2029. Blocked.',
    );
    expect(node, isSemantics(isButton: false, hasTapAction: false));
    handle.dispose();
  });

  testWidgets('active card shows no badge; zero balance shows "Used up"', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, BalanceCard(data: _card(), money: testMoney));
    expect(find.byType(StatusBadge), findsNothing);
    await pumpComponent(
      tester,
      BalanceCard(data: _card(balance: 0), money: testMoney),
    );
    expect(find.text('Used up', findRichText: true), findsOneWidget);
  });

  testWidgets('contrast fallback: a mid grey falls back to brand ink', (
    WidgetTester tester,
  ) async {
    int fallbacks = 0;
    await pumpComponent(
      tester,
      BalanceCard(
        data: _card(brand: '#767676'),
        money: testMoney,
        onContrastFallback: () => fallbacks++,
      ),
    );
    await tester.pump();
    expect(fallbacks, greaterThanOrEqualTo(1));
    final WaiterColors c = WaiterColors.resolve(Brightness.light);
    final BrandCardColors resolved = resolveBrandCardColors(
      brandColor: '#767676',
      colors: c,
      elevation: WaiterElevation.resolve(c),
    );
    expect(resolved.isContrastFallback, isTrue);
    final Iterable<ShapeDecoration> fills = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(BalanceCard),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((DecoratedBox d) => d.decoration)
        .whereType<ShapeDecoration>();
    expect(
      fills.any(
        (ShapeDecoration d) =>
            d.gradient is LinearGradient &&
            (d.gradient! as LinearGradient).colors.first == resolved.sheenStart,
      ),
      isTrue,
      reason: 'the card paints the ink fallback sheen',
    );
  });

  testWidgets('good brand colour does not fall back', (
    WidgetTester tester,
  ) async {
    int fallbacks = 0;
    await pumpComponent(
      tester,
      BalanceCard(
        data: _card(),
        money: testMoney,
        onContrastFallback: () => fallbacks++,
      ),
    );
    await tester.pump();
    expect(fallbacks, 0);
  });

  testWidgets('skeleton: brand fill, busy label, then content cross-fade', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      const BalanceCard(
        data: null,
        money: testMoney,
        skeletonBrandColor: '#7A1F2B',
      ),
    );
    expect(find.byType(SkeletonBox), findsNWidgets(3));
    expect(find.bySemanticsLabel('Checking voucher\u00A0…'), findsOneWidget);
    await pumpComponent(tester, BalanceCard(data: _card(), money: testMoney));
    await tester.pump(const Duration(milliseconds: 160));
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byType(SkeletonBox), findsNothing);
    handle.dispose();
  });

  testWidgets('arrival springs in; Reduce Motion only fades', (
    WidgetTester tester,
  ) async {
    await pumpComponent(
      tester,
      BalanceCard(data: _card(), money: testMoney, arrivalScale: 0.4),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(Transform), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
    await pumpComponent(tester, const SizedBox());
    await pumpComponent(
      tester,
      BalanceCard(data: _card(), money: testMoney, arrivalScale: 0.4),
      reduceMotion: true,
    );
    await tester.pump(const Duration(milliseconds: 80));
    final FadeTransition fade = tester.widget<FadeTransition>(
      find
          .descendant(
            of: find.byType(BalanceCard),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('swapping cards cross-fades over 300 ms', (
    WidgetTester tester,
  ) async {
    await pumpComponent(tester, BalanceCard(data: _card(), money: testMoney));
    await pumpComponent(
      tester,
      BalanceCard(
        data: _card(last4: '1234'),
        money: testMoney,
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.textContaining('6488', findRichText: true), findsOneWidget);
    expect(find.textContaining('1234', findRichText: true), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 151));
    expect(find.textContaining('6488', findRichText: true), findsNothing);
  });
}
