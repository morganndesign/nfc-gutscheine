import 'package:flutter/foundation.dart' show immutable;

/// What a key press did; drives feedback (05 §2.1 Keypad, 11 E30/E33).
enum EntryOutcome {
  /// Input applied — `haptic.key`, AmountDisplay roll-in (06 M12).
  accepted,

  /// Nothing changed and no feedback: `0` / `00` at amount 0 (03b §2.9),
  /// ⌫ or clear on an empty entry.
  ignored,

  /// Limit reached, input rejected — `haptic.warning` + ±3 pt limit nudge
  /// (03b §2.9, 13 · R18).
  rejectedAtLimit,

  /// ⌫ removed the last digit.
  deleted,

  /// Long-press ⌫ cleared the entry — `haptic.select`.
  cleared,

  /// Paste rejected (card number only): `manual.error.paste` (03a §7).
  pasteRejected,
}

/// Result of applying one input to an entry.
@immutable
class EntryChange<T> {
  /// Creates a change record.
  const EntryChange(this.value, this.outcome);

  /// Entry after the input (identical to the previous one unless the
  /// outcome is [EntryOutcome.accepted], [EntryOutcome.deleted] or
  /// [EntryOutcome.cleared]).
  final T value;

  /// What the input did.
  final EntryOutcome outcome;
}

/// POS-style amount entry of S07 (03b §2.9, 05 §2.1–2.2, 06 M12): digits
/// shift in from the right, the value is the typed digits ÷ 100, max 7
/// digits (€ 99.999,99).
///
/// ```dart
/// var e = AmountEntry.empty;
/// for (final d in [2, 4, 9, 0]) { e = e.digit(d).value; }
/// e.cents; // 2490 → "€ 24,90"
/// ```
@immutable
class AmountEntry {
  const AmountEntry._(this.digits);

  /// Amount 0, nothing typed.
  static const AmountEntry empty = AmountEntry._('');

  /// Maximum number of digits (03b §2.9: 7 digits = € 99.999,99).
  static const int maxDigits = 7;

  /// Largest enterable amount in cents.
  static const int maxCents = 9999999;

  /// Entry holding [cents], e.g. after the QuickAmountChip "Use balance" /
  /// "Use maximum" (03b §2.9). Throws [RangeError] outside 0…[maxCents].
  factory AmountEntry.fromCents(int cents) {
    RangeError.checkValueInInterval(cents, 0, maxCents, 'cents');
    return cents == 0 ? empty : AmountEntry._(cents.toString());
  }

  /// Typed digits without leading zeros (`''` for 0). Its length is the
  /// number of significant digits: the AmountDisplay shows the remaining
  /// implicit positions of `0,00` in the placeholder colour (05 §2.2).
  final String digits;

  /// Amount in cents.
  int get cents => digits.isEmpty ? 0 : int.parse(digits);

  /// Whether the amount is 0.
  bool get isEmpty => digits.isEmpty;

  /// Whether no further digit fits.
  bool get isFull => digits.length >= maxDigits;

  /// Digit key 0–9. `0` at amount 0 is ignored; an 8th digit is rejected.
  EntryChange<AmountEntry> digit(int digit) {
    RangeError.checkValueInInterval(digit, 0, 9, 'digit');
    if (digit == 0 && isEmpty) {
      return EntryChange<AmountEntry>(this, EntryOutcome.ignored);
    }
    if (isFull) {
      return EntryChange<AmountEntry>(this, EntryOutcome.rejectedAtLimit);
    }
    return EntryChange<AmountEntry>(
      AmountEntry._('$digits$digit'),
      EntryOutcome.accepted,
    );
  }

  /// `00` key. Ignored at amount 0; adds one `0` when only one digit fits
  /// (03b §2.9); rejected when full.
  EntryChange<AmountEntry> doubleZero() {
    if (isEmpty) {
      return EntryChange<AmountEntry>(this, EntryOutcome.ignored);
    }
    if (isFull) {
      return EntryChange<AmountEntry>(this, EntryOutcome.rejectedAtLimit);
    }
    final int free = maxDigits - digits.length;
    return EntryChange<AmountEntry>(
      AmountEntry._(digits + (free >= 2 ? '00' : '0')),
      EntryOutcome.accepted,
    );
  }

  /// ⌫ tap: removes the last digit (`24,90` → `2,49`).
  EntryChange<AmountEntry> backspace() {
    if (isEmpty) {
      return EntryChange<AmountEntry>(this, EntryOutcome.ignored);
    }
    return EntryChange<AmountEntry>(
      AmountEntry._(digits.substring(0, digits.length - 1)),
      EntryOutcome.deleted,
    );
  }

  /// ⌫ long press (500 ms): clears to 0.
  ///
  /// The ⌫ touch-down has already deleted one digit (05 §2.1: "part of the
  /// clear"); call [clear] on the entry as it was *before* that touch-down
  /// so a one-digit amount still reports [EntryOutcome.cleared].
  EntryChange<AmountEntry> clear() => EntryChange<AmountEntry>(
    empty,
    isEmpty ? EntryOutcome.ignored : EntryOutcome.cleared,
  );

  @override
  bool operator ==(Object other) =>
      other is AmountEntry && other.digits == digits;

  @override
  int get hashCode => digits.hashCode;

  @override
  String toString() => 'AmountEntry($cents)';
}
