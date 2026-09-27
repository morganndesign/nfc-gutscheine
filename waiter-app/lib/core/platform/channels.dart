import 'package:flutter/services.dart';

/// Platform channels implemented in MainActivity.kt / AppDelegate.swift.
abstract final class WaiterChannels {
  static const MethodChannel nfc = MethodChannel('giftcard_waiter/nfc');
  static const EventChannel nfcEvents = EventChannel('giftcard_waiter/nfc/events');
  static const MethodChannel feedback = MethodChannel('giftcard_waiter/feedback');
  static const MethodChannel system = MethodChannel('giftcard_waiter/system');
}
