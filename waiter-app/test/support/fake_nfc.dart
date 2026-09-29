import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:giftcard_waiter/core/platform/nfc_relay.dart';

/// A phone's card reader with one scripted NTAG 424 DNA card on it. It answers the fixed commands the app sends
/// (select, read NDEF, AuthenticateEV2First) like the chip does; the server side is scripted in FakeBackend.
class FakeNfcRelay implements NfcRelay {
  FakeNfcRelay({this.available = NfcAvailability.ready});

  NfcAvailability available;

  /// The card that will be tapped next; null: the waiter never taps (the future stays open until cancelled).
  FakeCard? card = FakeCard();

  /// Fails `start` with this instead of returning a card.
  NfcFailure? startFailure;

  /// Every APDU sent, hex.
  final List<String> sent = <String>[];

  /// Messages the sessions were closed with (null = closed without a message).
  final List<({String? message, bool failed})> closed = <({String? message, bool failed})>[];

  final List<String> prompts = <String>[];

  Completer<CardLink>? _waiting;

  @override
  Future<NfcAvailability> availability() async => available;

  @override
  Future<CardLink> start({required String prompt}) {
    prompts.add(prompt);
    if (startFailure != null) return Future<CardLink>.error(NfcRelayException(startFailure!));
    final FakeCard? next = card;
    if (next == null) {
      _waiting = Completer<CardLink>();
      return _waiting!.future;
    }
    return Future<CardLink>.value(_FakeLink(this, next));
  }

  /// The waiter closes the iPhone sheet while no card was tapped.
  void cancelWaiting() => _waiting?.completeError(const NfcRelayException(NfcFailure.cancelled));
}

class FakeCard {
  FakeCard({
    this.uidHex = '04A39493CC8680',
    this.tapUrl = 'https://t.giftcardpro.at/ks-2026-01?e=4F2A0D6C5B7E9A1F3C8D2E4B6A0F1C3D&m=94EED9EE65337086',
    this.challengeHex = 'A04C124213C186F22399D33AC2A30215',
    this.answerHex = '3FA64DB5446D1F34CD6EA311167F5E4985B8920F1BE7C4F59C4B2E8BD7E3ED9A9100',
  });

  final String uidHex;
  final String tapUrl;
  final String challengeHex;
  final String answerHex;

  /// The card moves away when this command (hex prefix) is sent.
  String? loseOn;

  /// Answers this command (hex prefix) with this status word instead.
  ({String prefix, String sw})? refuse;
}

class _FakeLink implements CardLink {
  _FakeLink(this._relay, this._card);

  final FakeNfcRelay _relay;
  final FakeCard _card;

  @override
  String get uidHex => _card.uidHex;

  @override
  Future<Uint8List> transceive(Uint8List apdu) async {
    final String hex = apdu.map((int b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
    _relay.sent.add(hex);
    if (_card.loseOn != null && hex.startsWith(_card.loseOn!)) throw const NfcRelayException(NfcFailure.tagLost);
    final ({String prefix, String sw})? refuse = _card.refuse;
    if (refuse != null && hex.startsWith(refuse.prefix)) return _bytes(refuse.sw);
    if (hex.startsWith('00A40400')) return _bytes('9000');
    if (hex.startsWith('00A4000C')) return _bytes('9000');
    if (hex.startsWith('00B00000')) return Uint8List.fromList(<int>[..._ndefFile(_card.tapUrl), 0x90, 0x00]);
    if (hex.startsWith('90710000')) return _bytes('${_card.challengeHex}91AF');
    if (hex.startsWith('90AF0000')) return _bytes(_card.answerHex);
    return _bytes('6D00');
  }

  @override
  Future<void> close({String? message, bool failed = false}) async {
    _relay.closed.add((message: message, failed: failed));
  }

  static Uint8List _bytes(String hex) =>
      Uint8List.fromList(<int>[for (int i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)]);

  /// NDEF file: NLEN, one short URI record with prefix 0x04 (https://).
  static List<int> _ndefFile(String url) {
    final List<int> uri = <int>[0x04, ...utf8.encode(url.replaceFirst('https://', ''))];
    final List<int> record = <int>[0xD1, 0x01, uri.length, 0x55, ...uri];
    return <int>[record.length >> 8, record.length & 0xFF, ...record];
  }
}
