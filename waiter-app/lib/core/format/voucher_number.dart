import 'package:flutter/foundation.dart' show immutable;

import 'amount_entry.dart' show EntryChange, EntryOutcome;
import 'money.dart' show noBreakSpace;

/// Card number formatting (12 §1.4, §4.2 `{number}` / `{last4}`) and the
/// S11 manual-entry rules (03a §7).
abstract final class CardNumber {
  /// Digits of a card number (03a §7).
  static const int length = 16;

  /// Four U+2022 bullets (12 §1.4).
  static const String bullets = '••••';

  /// Full number in groups of four joined by no-break spaces:
  /// `5285105870986488` → `5285 1058 7098 6488` (12 §1.4; S07 header and
  /// S11 only). A partial number is grouped the same way.
  ///
  /// Throws [FormatException] if [digits] contains a non-digit.
  static String format(String digits) {
    _checkDigits(digits);
    final List<String> groups = <String>[];
    for (int i = 0; i < digits.length; i += 4) {
      groups.add(
        digits.substring(i, i + 4 < digits.length ? i + 4 : digits.length),
      );
    }
    return groups.join(noBreakSpace);
  }

  /// Masked form `•••• 6488` (four bullets, no-break space, last four
  /// digits; 12 §1.4). Accepts the last four digits or a longer number.
  static String masked(String digits) =>
      '$bullets$noBreakSpace${lastFour(digits)}';

  /// Last four digits for `{last4}`. Throws [FormatException] if fewer than
  /// four digits or a non-digit are given.
  static String lastFour(String digits) {
    _checkDigits(digits);
    if (digits.length < 4) {
      throw FormatException('need at least 4 digits', digits);
    }
    return digits.substring(digits.length - 4);
  }

  /// Removes everything but the ASCII digits 0–9.
  static String digitsOnly(String text) =>
      text.replaceAll(RegExp('[^0-9]'), '');

  /// Paste rule of S11 (03a §7): all non-digits are stripped; exactly 16
  /// digits → the number; anything else → `null` (show
  /// `manual.error.paste`, keep the field unchanged).
  static String? fromPaste(String clipboard) {
    final String digits = digitsOnly(clipboard);
    return digits.length == length ? digits : null;
  }

  static void _checkDigits(String digits) {
    if (!RegExp(r'^[0-9]*$').hasMatch(digits)) {
      throw FormatException('card number must contain digits only', digits);
    }
  }
}

/// S11 card-number entry through the app keypad (03a §7, 05 §2.5): up to 16
/// digits, `00` inserts two zeros (one if only one position is left), ⌫,
/// long-press clear, paste. No Luhn / check-digit validation client-side
/// (03a §7: "the server decides").
@immutable
class CardNumberEntry {
  const CardNumberEntry._(this.digits);

  /// No digits typed.
  static const CardNumberEntry empty = CardNumberEntry._('');

  /// Entry restored from a previous number (S10 "Nummer bearbeiten", 03a §7).
  /// Throws [FormatException] for non-digits or more than 16 digits.
  factory CardNumberEntry.of(String digits) {
    if (!RegExp(r'^[0-9]*$').hasMatch(digits) ||
        digits.length > CardNumber.length) {
      throw FormatException('expected up to 16 digits', digits);
    }
    return CardNumberEntry._(digits);
  }

  /// Typed digits.
  final String digits;

  /// Count for `manual.counter` ("{count} von 16").
  int get count => digits.length;

  /// Whether all 16 digits are present ("Karte suchen" enabled).
  bool get isComplete => digits.length == CardNumber.length;

  /// Digit key 0–9; the 17th digit is rejected (03a §7).
  EntryChange<CardNumberEntry> digit(int digit) {
    RangeError.checkValueInInterval(digit, 0, 9, 'digit');
    if (isComplete) {
      return EntryChange<CardNumberEntry>(this, EntryOutcome.rejectedAtLimit);
    }
    return EntryChange<CardNumberEntry>(
      CardNumberEntry._('$digits$digit'),
      EntryOutcome.accepted,
    );
  }

  /// `00` key: two zeros, or one if only one position is left (03a §7).
  EntryChange<CardNumberEntry> doubleZero() {
    if (isComplete) {
      return EntryChange<CardNumberEntry>(this, EntryOutcome.rejectedAtLimit);
    }
    final int free = CardNumber.length - digits.length;
    return EntryChange<CardNumberEntry>(
      CardNumberEntry._(digits + (free >= 2 ? '00' : '0')),
      EntryOutcome.accepted,
    );
  }

  /// ⌫ tap: deletes one digit.
  EntryChange<CardNumberEntry> backspace() {
    if (digits.isEmpty) {
      return EntryChange<CardNumberEntry>(this, EntryOutcome.ignored);
    }
    return EntryChange<CardNumberEntry>(
      CardNumberEntry._(digits.substring(0, digits.length - 1)),
      EntryOutcome.deleted,
    );
  }

  /// ⌫ long press (500 ms): clears all digits.
  EntryChange<CardNumberEntry> clear() => EntryChange<CardNumberEntry>(
    empty,
    digits.isEmpty ? EntryOutcome.ignored : EntryOutcome.cleared,
  );

  /// Paste (03a §7): replaces the field with exactly 16 digits, otherwise
  /// leaves it unchanged with [EntryOutcome.pasteRejected].
  EntryChange<CardNumberEntry> paste(String clipboard) {
    final String? number = CardNumber.fromPaste(clipboard);
    if (number == null) {
      return EntryChange<CardNumberEntry>(this, EntryOutcome.pasteRejected);
    }
    return EntryChange<CardNumberEntry>(
      CardNumberEntry._(number),
      EntryOutcome.accepted,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CardNumberEntry && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;

  @override
  String toString() => 'CardNumberEntry(${digits.length} digits)';
}
