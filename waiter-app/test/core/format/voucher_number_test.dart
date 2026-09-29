import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/format/format.dart';

String nb(String s) => s.replaceAll(' ', ' ');

void main() {
  group('VoucherNumber', () {
    test('full number in groups of 4 with no-break spaces', () {
      expect(VoucherNumber.format('5285105870986488'), nb('5285 1058 7098 6488'));
      expect(VoucherNumber.format('528510'), nb('5285 10'));
      expect(VoucherNumber.format(''), '');
      expect(() => VoucherNumber.format('5285 1058'), throwsFormatException);
    });

    test('masked: four U+2022 bullets, no-break space, last four', () {
      expect(VoucherNumber.masked('6488'), nb('•••• 6488'));
      expect(VoucherNumber.masked('5285105870986488'), nb('•••• 6488'));
      expect(VoucherNumber.masked('6488').runes.take(4).toSet(), <int>{0x2022});
    });

    test('lastFour', () {
      expect(VoucherNumber.lastFour('5285105870986488'), '6488');
      expect(() => VoucherNumber.lastFour('648'), throwsFormatException);
    });
  });
}
