import 'package:flutter/foundation.dart';

import '../api/waiter_api.dart';

/// The restaurant's logo for the guest card (`BalanceCard`), loaded once per version and kept in memory: the URL
/// carries the logo's version, so a new logo is a new URL. Without a logo — or while it loads, or when it cannot be
/// loaded — the card shows the restaurant's name.
class RestaurantLogos extends ChangeNotifier {
  final Map<String, Uint8List> _images = <String, Uint8List>{};
  final Set<String> _loading = <String>{};

  /// Puts a logo in place (tests).
  @visibleForTesting
  void put(String url, Uint8List bytes) {
    _images[url] = bytes;
    notifyListeners();
  }

  /// The logo of [url] when it is already here.
  Uint8List? peek(String? url) => url == null ? null : _images[url];

  /// Loads the logo of [url] in the background (no-op when known, loading or null).
  Future<void> prefetch(WaiterApi api, String? url) async {
    if (url == null || _images.containsKey(url) || !_loading.add(url)) return;
    try {
      _images[url] = await api.logo(url);
      notifyListeners();
    } on Object {
      // The name stands in; the next start tries again.
    } finally {
      _loading.remove(url);
    }
  }
}

/// One store per app run.
final RestaurantLogos restaurantLogos = RestaurantLogos();
