import 'money.dart' show noBreakSpace;

/// Voucher number formatting (`{number}` / `{last4}`). The number is internal:
/// staff see it, it is never a credential and never printed for the guest.
abstract final class VoucherNumber {
  /// Four U+2022 bullets.
  static const String bullets = '••••';

  /// Full number in groups of four joined by no-break spaces:
  /// `5285105870986488` → `5285 1058 7098 6488` (S07 header).
  ///
  /// Throws [FormatException] if [digits] contains a non-digit.
  static String format(String digits) {
    _checkDigits(digits);
    final List<String> groups = <String>[];
    for (int i = 0; i < digits.length; i += 4) {
      groups.add(digits.substring(i, i + 4 < digits.length ? i + 4 : digits.length));
    }
    return groups.join(noBreakSpace);
  }

  /// Masked form `•••• 6488` (four bullets, no-break space, last four
  /// digits). Accepts the last four digits or a longer number.
  static String masked(String digits) => '$bullets$noBreakSpace${lastFour(digits)}';

  /// Last four digits for `{last4}`. Throws [FormatException] if fewer than
  /// four digits or a non-digit are given.
  static String lastFour(String digits) {
    _checkDigits(digits);
    if (digits.length < 4) throw FormatException('need at least 4 digits', digits);
    return digits.substring(digits.length - 4);
  }

  static void _checkDigits(String digits) {
    if (!RegExp(r'^[0-9]*$').hasMatch(digits)) {
      throw FormatException('voucher number must contain digits only', digits);
    }
  }
}
