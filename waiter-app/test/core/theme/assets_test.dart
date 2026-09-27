import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/theme/theme.dart';

/// Icons (10 §3, 04 §11) and illustrations (10 §4).
void main() {
  group('icons', () {
    test('46 icons: every file exists and follows the grid rules', () {
      expect(WaiterIcon.values, hasLength(46));
      final Set<String> files = Directory('assets/icons')
          .listSync()
          .whereType<File>()
          .map((File f) => f.uri.pathSegments.last)
          .toSet();
      expect(
        files,
        WaiterIcon.values.map((WaiterIcon i) => '${i.fileName}.svg').toSet(),
        reason: 'no missing and no stray icon files',
      );
      for (final WaiterIcon icon in WaiterIcon.values) {
        final String svg = File(icon.assetName).readAsStringSync();
        expect(svg, contains('viewBox="0 0 24 24"'), reason: icon.name);
        expect(svg, contains('stroke="currentColor"'), reason: icon.name);
        expect(svg, contains('stroke-width="1.75"'), reason: icon.name);
        expect(svg, contains('stroke-linecap="round"'), reason: icon.name);
        expect(svg, contains('stroke-linejoin="round"'), reason: icon.name);
        expect(svg, contains('fill="none"'), reason: icon.name);
        expect(
          RegExp(r'fill="#').allMatches(svg).length,
          lessThanOrEqualTo(1),
          reason: '${icon.name}: only mask fills',
        );
      }
    });

    test('file names follow ic_<lucide-name> (10 §1.2)', () {
      expect(WaiterIcon.scanQrCode.fileName, 'ic_scan_qr_code');
      expect(WaiterIcon.x.fileName, 'ic_x');
      expect(WaiterIcon.nfcArcs.assetName, 'assets/icons/ic_nfc_arcs.svg');
      expect(WaiterIcon.volume2.fileName, 'ic_volume_2');
    });

    test('stroke compensation per size (04 §11.2)', () {
      double scale(IconSize s) =>
          WaiterIconView(WaiterIcon.x, size: s).strokeScale;
      // Stroke in pt = 1.75 × scale × size / 24.
      for (final IconSize s in IconSize.values) {
        expect(1.75 * scale(s) * s.size / 24, closeTo(s.stroke, 1e-9));
      }
      const WaiterIconView mark = WaiterIconView.mark(
        WaiterIcon.cardArcs,
        dimension: 96,
        strokeWidth: 5,
      );
      expect(1.75 * mark.strokeScale * 96 / 24, closeTo(5, 1e-9));
    });

    test('stroke rewrite scales every width, including mask cuts', () {
      const String svg =
          '<svg stroke-width="1.75"><path stroke-width="5.25"/></svg>';
      final String out = scaleSvgStrokes(svg, 2);
      expect(out, contains('stroke-width="3.5000"'));
      expect(out, contains('stroke-width="10.5000"'));
      expect(scaleSvgStrokes(svg, 1), svg);
    });

    test('accent arcs are addressable for recolouring', () {
      for (final WaiterIcon icon in <WaiterIcon>[
        WaiterIcon.nfcArcs,
        WaiterIcon.cardArcs,
      ]) {
        final String svg = File(icon.assetName).readAsStringSync();
        expect(
          RegExp(r'id="accent-arc-\d" stroke="currentColor"').allMatches(svg),
          isNotEmpty,
          reason: icon.name,
        );
      }
    });

    testWidgets('renders with semantics only when labelled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: waiterThemeData(Brightness.light),
          home: Row(
            children: <Widget>[
              WaiterIconView(WaiterIcon.x, semanticLabel: 'Close'),
              WaiterIconView(WaiterIcon.info, size: IconSize.s16),
            ],
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
      expect(tester.getSize(find.byType(SvgPicture).first), const Size(24, 24));
      expect(tester.getSize(find.byType(SvgPicture).last), const Size(16, 16));
    });
  });

  group('illustrations', () {
    test('10 illustrations with roles and budget', () {
      expect(WaiterIllustration.values, hasLength(10));
      int total = 0;
      for (final WaiterIllustration ill in WaiterIllustration.values) {
        final File file = File(ill.assetName);
        final String svg = file.readAsStringSync();
        total += file.lengthSync();
        expect(
          file.lengthSync(),
          lessThanOrEqualTo(6 * 1024),
          reason: ill.name,
        );
        final String a = ill.artboard.toInt().toString();
        expect(svg, contains('viewBox="0 0 $a $a"'), reason: ill.name);
        expect(svg, contains('stroke-width="1.75"'), reason: ill.name);
        expect(
          svg,
          contains('<g id="line" stroke="#0000FE">'),
          reason: ill.name,
        );
        // Exactly one saffron accent group per illustration (10 §4.2).
        expect(
          '<g id="accent"'.allMatches(svg),
          hasLength(1),
          reason: ill.name,
        );
        // Only role placeholder colours; no status colours.
        final Set<String> colours = RegExp(
          r'#[0-9A-Fa-f]{6}',
        ).allMatches(svg).map((Match m) => m.group(0)!.toUpperCase()).toSet();
        expect(
          colours.difference(<String>{'#0000FE', '#FE0000', '#00FE00'}),
          isEmpty,
          reason: ill.name,
        );
        expect(svg, isNot(contains('<text')), reason: ill.name);
      }
      expect(total, lessThanOrEqualTo(80 * 1024));
    });

    test('sizes per use (10 §4.3)', () {
      WaiterLayout at(double h) =>
          WaiterLayout.fromWindow(Size(390, h), EdgeInsets.zero);
      expect(IllustrationUse.problem.sizeFor(at(844)), 120);
      expect(IllustrationUse.problem.sizeFor(at(667)), 96);
      expect(IllustrationUse.empty.sizeFor(at(667)), 96);
      expect(IllustrationUse.intro.sizeFor(at(844)), 160);
      expect(IllustrationUse.intro.sizeFor(at(667)), 120);
      expect(WaiterIllustration.introTap.use, IllustrationUse.intro);
      expect(WaiterIllustration.recentEmpty.artboard, 96);
    });

    test('stroke stays 1.75 pt at every size, +0.25 in high contrast', () {
      for (final double size in <double>[96, 120, 160]) {
        final double s = IllustrationView.strokeScaleFor(
          WaiterIllustration.cardNotFound,
          size,
          highContrast: false,
        );
        expect(1.75 * s * size / 120, closeTo(1.75, 1e-9));
        final double hc = IllustrationView.strokeScaleFor(
          WaiterIllustration.cardNotFound,
          size,
          highContrast: true,
        );
        expect(1.75 * hc * size / 120, closeTo(2.0, 1e-9));
      }
    });

    testWidgets('renders decoratively at the use size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: waiterThemeData(Brightness.dark),
          home: const Center(
            child: IllustrationView(WaiterIllustration.cardNotFound),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      // Test window is 800 × 600: compact height → 96 pt.
      expect(tester.getSize(find.byType(SvgPicture)), const Size(96, 96));
    });
  });

  test('sounds ship only as platform files, not Flutter assets (10 §2.5)', () {
    expect(Directory('assets/sounds').existsSync(), isFalse);
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('assets/sounds')));
  });
}
