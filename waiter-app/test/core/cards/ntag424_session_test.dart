import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:giftcard_waiter/core/cards/ntag424_session.dart';

/// The fixed command sequence the phone relays, and the NDEF parsing of the card's tap URL.
void main() {
  Uint8List file(List<int> record) => Uint8List.fromList(<int>[record.length >> 8, record.length & 0xFF, ...record]);

  test('a short URI record with the https:// prefix', () {
    const String rest = 't.giftcardpro.at/ks-2026-01?e=00&m=11';
    final List<int> uri = <int>[0x04, ...utf8.encode(rest)];
    expect(Ntag424Session.parseNdefUri(file(<int>[0xD1, 0x01, uri.length, 0x55, ...uri])), 'https://$rest');
  });

  test('a long record and an id field are read correctly', () {
    const String rest = 't.giftcardpro.at/ks-2026-01?e=AA&m=BB';
    final List<int> uri = <int>[0x04, ...utf8.encode(rest)];
    final List<int> long = <int>[0xC1, 0x01, 0, 0, 0, uri.length, 0x55, ...uri];
    expect(Ntag424Session.parseNdefUri(file(long)), 'https://$rest');
    final List<int> withId = <int>[0xD9, 0x01, uri.length, 2, 0x55, 0x61, 0x62, ...uri];
    expect(Ntag424Session.parseNdefUri(file(withId)), 'https://$rest');
  });

  test('anything that is not one URI record is refused', () {
    for (final List<int> bad in <List<int>>[
      <int>[0xD1, 0x01, 3, 0x54, 0x02, 0x65, 0x6E], // text record
      <int>[0xD2, 0x0A, 3, 0x61, 0x62, 0x63], // MIME record
      <int>[0xD1, 0x01, 40, 0x55, 0x04], // truncated
    ]) {
      expect(() => Ntag424Session.parseNdefUri(file(bad)), throwsA(isA<CardProtocolException>()));
    }
    expect(
      () => Ntag424Session.parseNdefUri(Uint8List.fromList(<int>[0, 50, 1])),
      throwsA(isA<CardProtocolException>()),
    );
  });

  test('a blank card from the factory (empty NDEF file) is refused, never a crash', () {
    for (final List<int> blank in <List<int>>[
      List<int>.filled(32, 0), // NLEN 0
      <int>[0x00, 0x03, 0xD0, 0x00, 0x00, 0, 0, 0], // empty record
      List<int>.filled(256, 0xFF),
      <int>[0x00, 0x08, 0xD1, 0x01, 0x04, 0x55, 0x04, 0xC3, 0x28, 0x00], // invalid UTF-8
    ]) {
      expect(() => Ntag424Session.parseNdefUri(Uint8List.fromList(blank)), throwsA(isA<CardProtocolException>()));
    }
  });
}
