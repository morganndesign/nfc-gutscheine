import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'channels.dart';

/// NFC hardware state (S05 variants `nfcOff`, `nfcUnsupported`; 09 §7.1).
enum NfcAvailability { enabled, disabled, unsupported }

/// Why an iPhone NFC session ended without a card being accepted (09 §7.2).
enum NfcSessionEnd { userCancelled, timeout, systemBusy, unavailable }

@immutable
sealed class NfcEvent {
  const NfcEvent();
}

/// A tag was read completely: the NDEF URI (if any) and the UID as upper-case
/// hex bytes joined by colons (`04:A2:3F:1B:6C:80:12`).
final class NfcTagRead extends NfcEvent {
  const NfcTagRead({required this.uid, this.url});

  final String uid;
  final String? url;
}

/// The read was interrupted or the tag was unreadable (L11).
final class NfcReadFailed extends NfcEvent {
  const NfcReadFailed();
}

/// Android adapter switched on/off in the system settings.
final class NfcAdapterChanged extends NfcEvent {
  const NfcAdapterChanged(this.availability);

  final NfcAvailability availability;
}

/// iPhone: the system sheet closed (cancel, ≈ 60 s timeout, busy).
final class NfcSessionEnded extends NfcEvent {
  const NfcSessionEnded(this.reason);

  final NfcSessionEnd reason;
}

/// The texts the iPhone system sheet shows (09 §7.2, `ios.sheet.*`).
@immutable
class IosSheetTexts {
  const IosSheetTexts({
    required this.alert,
    required this.found,
    required this.multiple,
    required this.readFailed,
    required this.timeoutSoon,
    required this.notCard,
  });

  final String alert;
  final String found;
  final String multiple;
  final String readFailed;
  final String timeoutSoon;
  final String notCard;

  Map<String, String> toMap() => <String, String>{
        'alert': alert,
        'found': found,
        'multiple': multiple,
        'readFailed': readFailed,
        'timeoutSoon': timeoutSoon,
        'notCard': notCard,
      };
}

/// Card reading on both platforms, over the app's own platform channel
/// (09 §8: flags the packages do not expose — NFC-A only, no platform sounds,
/// 250 ms presence check, ISO 14443 session with UID, restart-polling texts).
abstract interface class NfcService {
  Stream<NfcEvent> get events;

  Future<NfcAvailability> availability();

  /// Android: reader mode on the foreground activity (Ready, Charge, Success,
  /// Problem). No-op on iOS.
  Future<void> setReaderMode({required bool enabled});

  /// iPhone: opens the system sheet (only on a user action).
  Future<void> startSession(IosSheetTexts texts);

  /// iPhone: the tag was accepted — shows `ios.sheet.found` and closes the sheet.
  Future<void> finishSession();

  /// iPhone: the tag is not a gift card — shows `scan.notCard` and polls again
  /// after 1 s.
  Future<void> rejectTag();

  /// Android: opens the system NFC settings (S16 `nfcOff`).
  Future<void> openSettings();
}

class PlatformNfcService implements NfcService {
  PlatformNfcService({
    MethodChannel channel = WaiterChannels.nfc,
    EventChannel events = WaiterChannels.nfcEvents,
  })  : _channel = channel,
        _events = events;

  final MethodChannel _channel;
  final EventChannel _events;

  Stream<NfcEvent>? _stream;

  @override
  Stream<NfcEvent> get events => _stream ??= _events
      .receiveBroadcastStream()
      .map(_decode)
      .where((NfcEvent? e) => e != null)
      .cast<NfcEvent>()
      .asBroadcastStream();

  static NfcEvent? _decode(Object? raw) {
    if (raw is! Map) return null;
    final Map<Object?, Object?> m = raw;
    switch (m['type']) {
      case 'tag':
        final Object? uid = m['uid'];
        if (uid is! String || uid.isEmpty) return const NfcReadFailed();
        final Object? url = m['url'];
        return NfcTagRead(uid: uid, url: url is String && url.isNotEmpty ? url : null);
      case 'readFailed':
        return const NfcReadFailed();
      case 'adapter':
        return NfcAdapterChanged(_availability(m['state']));
      case 'sessionEnded':
        return NfcSessionEnded(switch (m['reason']) {
          'timeout' => NfcSessionEnd.timeout,
          'busy' => NfcSessionEnd.systemBusy,
          'unavailable' => NfcSessionEnd.unavailable,
          _ => NfcSessionEnd.userCancelled,
        });
    }
    return null;
  }

  static NfcAvailability _availability(Object? value) => switch (value) {
        'enabled' => NfcAvailability.enabled,
        'disabled' => NfcAvailability.disabled,
        _ => NfcAvailability.unsupported,
      };

  @override
  Future<NfcAvailability> availability() async {
    try {
      return _availability(await _channel.invokeMethod<String>('availability'));
    } on MissingPluginException {
      return NfcAvailability.unsupported;
    }
  }

  @override
  Future<void> setReaderMode({required bool enabled}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _channel.invokeMethod<void>('readerMode', <String, Object?>{'enabled': enabled});
  }

  @override
  Future<void> startSession(IosSheetTexts texts) =>
      _channel.invokeMethod<void>('startSession', texts.toMap());

  @override
  Future<void> finishSession() => _channel.invokeMethod<void>('finishSession');

  @override
  Future<void> rejectTag() => _channel.invokeMethod<void>('rejectTag');

  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');
}
