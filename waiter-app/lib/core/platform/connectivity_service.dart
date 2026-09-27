import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// OS reachability as a hint only (02 §4.5.3 NETWORK_DOWN/UP): it never blocks
/// a lookup; it blocks sending a redeem (I2) and drives the offline banner.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  /// For tests: starts in [online] and never listens to the platform.
  @visibleForTesting
  ConnectivityService.fixed({bool online = true})
      : _connectivity = null,
        _online = online;

  final Connectivity? _connectivity;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _online = true;

  bool get isOnline => _online;

  Future<void> start() async {
    final Connectivity? c = _connectivity;
    if (c == null) return;
    _apply(await c.checkConnectivity());
    _subscription = c.onConnectivityChanged.listen(_apply);
  }

  @visibleForTesting
  void setOnline(bool value) {
    if (value == _online) return;
    _online = value;
    notifyListeners();
  }

  void _apply(List<ConnectivityResult> results) =>
      setOnline(results.any((ConnectivityResult r) => r != ConnectivityResult.none));

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
