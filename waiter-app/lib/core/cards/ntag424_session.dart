import 'dart:convert';
import 'dart:typed_data';

import '../platform/nfc_relay.dart';

/// What the server needs to start a card's live authentication (POST /presentments/cards).
class CardTap {
  const CardTap({required this.tapUrl, required this.rfUidHex, required this.challengeHex});

  /// The NDEF URI the card wrote for this read (SUN: https://t…/{k}?e=…&m=…).
  final String tapUrl;

  /// The UID the phone saw on the radio layer.
  final String rfUidHex;

  /// The card's answer to AuthenticateEV2First part 1, E(K3, RndB).
  final String challengeHex;
}

class CardProtocolException implements Exception {
  const CardProtocolException(this.step);

  /// Which command the card refused (for the log; never shown).
  final String step;

  @override
  String toString() => 'CardProtocolException($step)';
}

/// The fixed NTAG 424 DNA command sequence the phone relays. It reads only what the card shows anyone (its
/// NDEF URL) and starts the authentication; everything that needs a key happens on the server.
abstract final class Ntag424Session {
  static final Uint8List _selectApplication = _hex('00A4040007D276000085010100');
  static final Uint8List _selectNdefFile = _hex('00A4000C02E104');
  static final Uint8List _readNdefFile = _hex('00B0000000');

  /// AuthenticateEV2First with key 3 (the live challenge key; no write rights).
  static final Uint8List _authenticateKey3 = _hex('9071000002030000');

  static Future<CardTap> read(CardLink card) async {
    await _expect(card, _selectApplication, 'select application', ok: _iso);
    await _expect(card, _selectNdefFile, 'select NDEF file', ok: _iso);
    final Uint8List file = await _expect(card, _readNdefFile, 'read NDEF file', ok: _iso);
    final String url = parseNdefUri(file);
    final Uint8List challenge = await _expect(card, _authenticateKey3, 'authenticate', ok: _additionalFrame);
    if (challenge.length != 16) throw const CardProtocolException('authenticate');

    return CardTap(tapUrl: url, rfUidHex: card.uidHex, challengeHex: hexOf(challenge));
  }

  /// Relays the server's command (AuthenticateEV2First part 2) and returns the card's full answer as hex
  /// (32 bytes and 91 00). A refusal by the card is still returned: the server decides.
  static Future<String> answer(CardLink card, String commandHex) async {
    final Uint8List answer = await card.transceive(_hex(commandHex));
    return hexOf(answer);
  }

  /// The URI of the first NDEF record of an NDEF file (2-byte NLEN, then the message). An empty or malformed file
  /// (a blank card from the factory, another tag) is a [CardProtocolException], never a crash.
  static String parseNdefUri(Uint8List file) {
    try {
      return _parseNdefUri(file);
    } on CardProtocolException {
      rethrow;
    } on Object {
      throw const CardProtocolException('NDEF');
    }
  }

  static String _parseNdefUri(Uint8List file) {
    if (file.length < 7) throw const CardProtocolException('NDEF');
    final int length = (file[0] << 8) | file[1];
    if (length < 5 || length + 2 > file.length) throw const CardProtocolException('NDEF');
    final Uint8List message = Uint8List.sublistView(file, 2, 2 + length);
    final int header = message[0];
    final bool shortRecord = (header & 0x10) != 0;
    final bool hasId = (header & 0x08) != 0;
    final int typeLength = message[1];
    int offset = 2;
    int payloadLength;
    if (shortRecord) {
      payloadLength = message[offset];
      offset += 1;
    } else {
      if (message.length < offset + 4) throw const CardProtocolException('NDEF');
      payloadLength =
          (message[offset] << 24) | (message[offset + 1] << 16) | (message[offset + 2] << 8) | message[offset + 3];
      offset += 4;
    }
    final int idLength = hasId ? message[offset++] : 0;
    if ((header & 0x07) != 0x01 || typeLength != 1 || message[offset] != 0x55) {
      throw const CardProtocolException('NDEF');
    }
    offset += typeLength + idLength;
    if (offset + payloadLength > message.length || payloadLength < 1) throw const CardProtocolException('NDEF');
    final int prefix = message[offset];
    final String rest = utf8.decode(Uint8List.sublistView(message, offset + 1, offset + payloadLength));
    return switch (prefix) {
      0x04 => 'https://$rest',
      0x03 => 'http://$rest',
      0x02 => 'https://www.$rest',
      0x01 => 'http://www.$rest',
      0x00 => rest,
      _ => throw const CardProtocolException('NDEF'),
    };
  }

  static bool _iso(int sw1, int sw2) => sw1 == 0x90 && sw2 == 0x00;

  static bool _additionalFrame(int sw1, int sw2) => sw1 == 0x91 && sw2 == 0xAF;

  static Future<Uint8List> _expect(
    CardLink card,
    Uint8List apdu,
    String step, {
    required bool Function(int, int) ok,
  }) async {
    final Uint8List answer = await card.transceive(apdu);
    if (answer.length < 2) throw CardProtocolException(step);
    final int sw1 = answer[answer.length - 2];
    final int sw2 = answer[answer.length - 1];
    if (!ok(sw1, sw2)) throw CardProtocolException(step);
    return Uint8List.sublistView(answer, 0, answer.length - 2);
  }

  static String hexOf(Uint8List bytes) =>
      bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

  static Uint8List _hex(String hex) {
    final Uint8List out = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static Uint8List bytesOf(String hex) => _hex(hex);
}
