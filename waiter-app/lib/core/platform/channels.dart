import 'package:flutter/services.dart';

/// Platform channels implemented in MainActivity.kt / WaiterPlatformPlugin.swift.
abstract final class WaiterChannels {
  static const MethodChannel feedback = MethodChannel('giftcard_waiter/feedback');
  static const MethodChannel system = MethodChannel('giftcard_waiter/system');
}
