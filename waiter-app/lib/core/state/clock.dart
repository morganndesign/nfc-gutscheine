import 'dart:async';

/// Monotonic time for every timer of the loop (09 §4.1 rule 3): wall-clock or
/// time-zone changes never shorten or extend a countdown.
abstract interface class MonotonicClock {
  Duration now();

  Timer timer(Duration after, void Function() callback);
}

class SystemMonotonicClock implements MonotonicClock {
  SystemMonotonicClock() : _watch = Stopwatch()..start();

  final Stopwatch _watch;

  @override
  Duration now() => _watch.elapsed;

  @override
  Timer timer(Duration after, void Function() callback) => Timer(after, callback);
}
