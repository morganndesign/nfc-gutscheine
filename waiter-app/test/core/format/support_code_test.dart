import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/format/format.dart';

void main() {
  group('SupportCode — 12 §2.5, 13 · R02', () {
    test('last 6 characters, upper case, no hyphens', () {
      expect(
        SupportCode.fromRequestId('9b2f6c1e-3d4a-4e8b-a1c2-4b1e9c7f3a9c'),
        '7F3A9C',
      );
    });

    test('hyphens are removed before taking 6 characters', () {
      expect(SupportCode.fromRequestId('abcd-ef-12-34'), 'EF1234');
    });

    test('too short → FormatException', () {
      expect(() => SupportCode.fromRequestId('ab-cd'), throwsFormatException);
    });

    test('screen reader reads characters singly: "7 F 3 A 9 C"', () {
      expect(SupportCode.spoken('7F3A9C'), '7 F 3 A 9 C');
    });
  });
}
