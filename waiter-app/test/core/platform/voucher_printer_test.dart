import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/format/format.dart';
import 'package:giftcard_waiter/core/platform/voucher_printer.dart';

/// The printed voucher: the guest's language, no number, no value.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guest copy follows the restaurant locale (as the dashboard printout)', () {
    expect(GuestCopy.of('de_AT').voucher, 'Gutschein');
    expect(GuestCopy.of('bs_BA').voucher, 'Vaučer');
    expect(GuestCopy.of('hr').voucher, 'Vaučer');
    expect(GuestCopy.of('sr_Latn_RS').voucher, 'Vaučer');
    expect(GuestCopy.of('en_GB').voucher, 'Voucher');
    expect(GuestCopy.of('it_IT').voucher, 'Voucher');
  });

  test('no guest text carries a number or an amount', () {
    for (final String locale in <String>['de_AT', 'en_GB', 'bs_BA']) {
      final GuestCopy copy = GuestCopy.of(locale);
      final String all = <String>[copy.voucher, copy.howTo, copy.keepSafe, copy.noExpiry, copy.validUntil].join(' ');
      expect(all, isNot(matches(RegExp(r'[0-9€]'))), reason: locale);
    }
  });

  test('validity line uses the restaurant language date format', () {
    final CalendarDate date = CalendarDate(2029, 9, 26);
    expect(GuestCopy.of('de_AT').validity(date), 'Gültig bis 26.09.2029');
    expect(GuestCopy.of('de_AT').validity(null), 'Unbefristet gültig');
  });

  test('the sheet renders to a one-page A6 PDF with Latin Extended text', () async {
    final Uint8List pdf = await voucherSheetPdf(
      const PrintableVoucher(
        payload: 'GCPV1.AbCdEfGhIjKlMnOpQrStUvWxYz0123456789-_AbCdE',
        restaurantName: 'Ćevabdžinica Željo',
        restaurantLocale: 'bs_BA',
        brandColor: '#7A1F2B',
      ),
    );
    expect(String.fromCharCodes(pdf.take(5)), '%PDF-');
    expect(pdf.length, greaterThan(1000));
  });
}
