import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

Future<void> _loadGeist() async {
  final FontLoader geist = FontLoader('Geist');
  for (final String w in <String>['Regular', 'Medium', 'SemiBold', 'Bold']) {
    geist.addFont(rootBundle.load('assets/fonts/Geist-$w.ttf'));
  }
  await geist.load();
}

Widget _host(Widget child, {double scale = 1, double width = 390}) {
  return MaterialApp(
    theme: waiterThemeData(Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 844),
        textScaler: TextScaler.linear(scale),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

double _renderedSize(WidgetTester tester) {
  final RichText text = tester.widget<RichText>(find.byType(RichText).last);
  return (text.text as TextSpan).style!.fontSize!;
}

void main() {
  setUpAll(_loadGeist);

  group('per-style clamps (04 §3.7)', () {
    final Map<TypeSpec, double> caps = <TypeSpec, double>{
      TypeTokens.bodyL: 2.0,
      TypeTokens.caption: 2.0,
      TypeTokens.labelL: 2.0,
      TypeTokens.titleL: 1.5,
      TypeTokens.titleM: 1.5,
      TypeTokens.overline: 1.3,
      TypeTokens.key: 1.2,
    };
    for (final MapEntry<TypeSpec, double> e in caps.entries) {
      testWidgets('${e.key.name} caps at ${e.value * 100}%', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          _host(ScaledText('12', type: e.key), scale: 3.1),
        );
        expect(_renderedSize(tester), closeTo(e.key.fontSize * e.value, 1e-9));
        await tester.pumpWidget(
          _host(ScaledText('12', type: e.key), scale: 1.1),
        );
        expect(_renderedSize(tester), closeTo(e.key.fontSize * 1.1, 1e-9));
      });
    }

    testWidgets('extra cap inside the BalanceCard (130 %)', (tester) async {
      await tester.pumpWidget(
        _host(
          const ScaledText(
            'Zum Hirschen',
            type: TypeTokens.titleM,
            maxScale: 1.3,
          ),
          scale: 2,
        ),
      );
      expect(_renderedSize(tester), closeTo(22 * 1.3, 1e-9));
    });

    testWidgets('overline renders uppercase', (tester) async {
      await tester.pumpWidget(
        _host(const ScaledText('Gift card', type: TypeTokens.overline)),
      );
      final RichText text = tester.widget<RichText>(find.byType(RichText).last);
      expect(text.text.toPlainText(), 'GIFT CARD');
    });
  });

  group('shrink-to-fit', () {
    test('steps 2 pt down, never below the minimum', () {
      // Width proportional to size: 10 pt per pt of size.
      double widthAt(double s) => s * 10;
      expect(
        shrinkToFitSize(
          startSize: 83.2,
          minSize: 40,
          maxWidth: 600,
          widthAt: widthAt,
        ),
        closeTo(59.2, 1e-9),
      );
      expect(
        shrinkToFitSize(
          startSize: 83.2,
          minSize: 40,
          maxWidth: 100,
          widthAt: widthAt,
        ),
        40,
      );
      expect(
        shrinkToFitSize(
          startSize: 64,
          minSize: 40,
          maxWidth: double.infinity,
          widthAt: widthAt,
        ),
        64,
      );
    });

    testWidgets('amount caps at 130 % then shrinks to fit, min 40', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ScaledText('€ 24,90', type: TypeTokens.amountXl),
          scale: 2,
          width: 600,
        ),
      );
      expect(_renderedSize(tester), closeTo(64 * 1.3, 1e-9));

      await tester.pumpWidget(
        _host(
          const ScaledText('€ 99.999,99', type: TypeTokens.amountXl),
          scale: 2,
          width: 320,
        ),
      );
      final double size = _renderedSize(tester);
      expect(size, lessThan(64 * 1.3));
      expect(size, greaterThanOrEqualTo(40));
      final RichText text = tester.widget<RichText>(find.byType(RichText).last);
      expect(text.maxLines, 1);
      expect(
        tester.getSize(find.byType(RichText).last).width,
        lessThanOrEqualTo(320),
      );

      await tester.pumpWidget(
        _host(
          const ScaledText('€ 99.999,99', type: TypeTokens.amountXl),
          width: 150,
        ),
      );
      expect(_renderedSize(tester), 40);
    });

    testWidgets('rich spans scale together (currency keeps 60 %)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ScaledText.rich(
            (ScaledStyles s) => TextSpan(
              children: <InlineSpan>[
                TextSpan(text: '€', style: s(TypeTokens.currencyXl)),
                TextSpan(text: '24,90', style: s(TypeTokens.amountXl)),
              ],
            ),
            type: TypeTokens.amountXl,
          ),
          scale: 1.2,
        ),
      );
      final RichText text = tester.widget<RichText>(find.byType(RichText).last);
      final List<InlineSpan> parts = (text.text as TextSpan).children!;
      final double symbol = (parts[0] as TextSpan).style!.fontSize!;
      final double digits = (parts[1] as TextSpan).style!.fontSize!;
      expect(digits, closeTo(64 * 1.2, 1e-9));
      expect(symbol / digits, closeTo(38 / 64, 1e-9));
    });

    testWidgets('card number shrinks to min 20', (tester) async {
      final FontLoader mono = FontLoader('GeistMono')
        ..addFont(rootBundle.load('assets/fonts/GeistMono-Medium.ttf'));
      await mono.load();
      await tester.pumpWidget(
        _host(
          const ScaledText('5285 1058 7098 6488', type: TypeTokens.cardNumber),
          width: 120,
        ),
      );
      expect(_renderedSize(tester), 20);
    });
  });

  testWidgets('WaiterThemeScope caps the global scaler at 200 %, folds in '
      'Bold Text and high contrast', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          textScaler: TextScaler.linear(3),
          boldText: true,
          highContrast: true,
          platformBrightness: Brightness.dark,
        ),
        child: WaiterThemeScope(
          mode: ThemeMode.system,
          child: Builder(
            builder: (BuildContext context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(MediaQuery.textScalerOf(captured).scale(10), 20);
    expect(MediaQuery.boldTextOf(captured), isFalse);
    expect(captured.waiter.boldText, isTrue);
    expect(captured.waiter.isHighContrast, isTrue);
    expect(captured.colors.brightness, Brightness.dark);
    expect(captured.textStyles.bodyL.fontWeight, FontWeight.w500);
    expect(captured.waiter.focusRingWidth, 3);
    expect(captured.waiter.inputBorderWidth, 2);
    expect(captured.waiter.nfcArc, WaiterColors.dark.nfcArcHc);
  });

  test('resolveBrightness honours the Menu override', () {
    expect(
      WaiterThemeScope.resolveBrightness(ThemeMode.light, Brightness.dark),
      Brightness.light,
    );
    expect(
      WaiterThemeScope.resolveBrightness(ThemeMode.system, Brightness.dark),
      Brightness.dark,
    );
  });
}
