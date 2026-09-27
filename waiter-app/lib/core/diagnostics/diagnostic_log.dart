import 'dart:collection';

/// Local diagnostics (09 §4.1 rule 1): state transitions and request ids in a
/// ring buffer of 500 entries. Never contains card data, amounts, tokens or
/// idempotency keys, and is never sent anywhere in v1 (09 §10.3).
class DiagnosticLog {
  DiagnosticLog({this.capacity = 500, DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final int capacity;
  final DateTime Function() _clock;
  final Queue<DiagnosticEntry> _entries = Queue<DiagnosticEntry>();

  void record(String event, [String detail = '']) {
    _entries.addLast(DiagnosticEntry(_clock().toUtc(), event, detail));
    while (_entries.length > capacity) {
      _entries.removeFirst();
    }
  }

  List<DiagnosticEntry> get entries => List<DiagnosticEntry>.unmodifiable(_entries);

  void clear() => _entries.clear();
}

class DiagnosticEntry {
  const DiagnosticEntry(this.at, this.event, this.detail);

  final DateTime at;
  final String event;
  final String detail;

  @override
  String toString() => '${at.toIso8601String()} $event${detail.isEmpty ? '' : ' $detail'}';
}
