import 'package:flutter/services.dart';

import 'channels.dart';

/// Whether this phone can read cards now.
enum NfcAvailability { ready, disabled, unsupported }

/// Why a card session ended without an answer.
enum NfcFailure {
  /// The phone cannot read cards.
  unsupported,

  /// NFC is switched off (Android).
  disabled,

  /// The waiter closed the reader (iPhone sheet) or the app went to the background.
  cancelled,

  /// No card within the time the system allows (iPhone: 60 s).
  timeout,

  /// The card moved away during the exchange.
  tagLost,

  /// Another session is still open.
  busy,

  /// Anything else on the radio.
  io,
}

class NfcRelayException implements Exception {
  const NfcRelayException(this.failure, [this.message]);

  final NfcFailure failure;
  final String? message;

  static NfcRelayException from(PlatformException e) => NfcRelayException(switch (e.code) {
    'unsupported' => NfcFailure.unsupported,
    'disabled' => NfcFailure.disabled,
    'cancelled' => NfcFailure.cancelled,
    'timeout' => NfcFailure.timeout,
    'tag_lost' => NfcFailure.tagLost,
    'busy' => NfcFailure.busy,
    _ => NfcFailure.io,
  }, e.message);

  @override
  String toString() => 'NfcRelayException(${failure.name})';
}

/// A card on the phone: its radio UID and a byte pipe to it. The app never interprets keys or secrets; it
/// only relays what the server asks for.
abstract interface class CardLink {
  /// The 7-byte UID seen on the radio layer (upper-case hex).
  String get uidHex;

  /// Sends one APDU and returns the card's answer (data ‖ SW1 SW2).
  Future<Uint8List> transceive(Uint8List apdu);

  /// Ends the session. On iPhone [message] is shown on the system sheet (as an error when [failed]).
  Future<void> close({String? message, bool failed = false});
}

/// Android (reader mode, IsoDep) and iPhone (NFCTagReaderSession, ISO 7816) behave the same through this.
abstract interface class NfcRelay {
  Future<NfcAvailability> availability();

  /// Waits for a card; [prompt] is the text of the iPhone system sheet.
  Future<CardLink> start({required String prompt});

  /// Ends a session that is still waiting for a card (its [start] fails with [NfcFailure.cancelled]).
  Future<void> cancel();
}

class PlatformNfcRelay implements NfcRelay {
  const PlatformNfcRelay([this._channel = WaiterChannels.nfc]);

  final MethodChannel _channel;

  @override
  Future<NfcAvailability> availability() async {
    try {
      return switch (await _channel.invokeMethod<String>('availability')) {
        'ready' => NfcAvailability.ready,
        'disabled' => NfcAvailability.disabled,
        _ => NfcAvailability.unsupported,
      };
    } on MissingPluginException {
      return NfcAvailability.unsupported;
    } on PlatformException {
      return NfcAvailability.unsupported;
    }
  }

  @override
  Future<CardLink> start({required String prompt}) async {
    try {
      final Map<Object?, Object?>? answer = await _channel.invokeMapMethod<Object?, Object?>('start', <String, Object?>{
        'prompt': prompt,
      });
      final Object? uid = answer?['uid'];
      if (uid is! String) throw const NfcRelayException(NfcFailure.io);
      return _PlatformCardLink(_channel, uid.toUpperCase());
    } on PlatformException catch (e) {
      throw NfcRelayException.from(e);
    } on MissingPluginException {
      throw const NfcRelayException(NfcFailure.unsupported);
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('stop', <String, Object?>{'message': null, 'failed': false});
    } on PlatformException {
      // Nothing open.
    } on MissingPluginException {
      // No reader on this platform.
    }
  }
}

class _PlatformCardLink implements CardLink {
  _PlatformCardLink(this._channel, this.uidHex);

  final MethodChannel _channel;

  @override
  final String uidHex;

  @override
  Future<Uint8List> transceive(Uint8List apdu) async {
    try {
      final Uint8List? answer = await _channel.invokeMethod<Uint8List>('transceive', <String, Object?>{'apdu': apdu});
      if (answer == null || answer.length < 2) throw const NfcRelayException(NfcFailure.io);
      return answer;
    } on PlatformException catch (e) {
      throw NfcRelayException.from(e);
    }
  }

  @override
  Future<void> close({String? message, bool failed = false}) async {
    try {
      await _channel.invokeMethod<void>('stop', <String, Object?>{'message': message, 'failed': failed});
    } on PlatformException {
      // Already closed by the system.
    }
  }
}
