import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'channels.dart';
import 'nfc_service.dart';

/// What the phone found out about the tag on it (S20).
@immutable
class TagInfo {
  const TagInfo({required this.uid, required this.type, required this.writable, required this.maxSize});

  /// `04:A2:3F:1B:6C:80:12`.
  final String uid;

  /// `ntag213`, `ntag215`, `ntag216`, or null for any other chip (e.g. NTAG 424 DNA).
  final String? type;
  final bool writable;

  /// Usable NDEF bytes, -1 when unknown (unformatted tag).
  final int maxSize;
}

/// A tag operation failed on the phone. [code]: `NO_TAG`, `TAG_LOST`, `IO_FAILED`, `READ_ONLY`,
/// `TOO_SMALL`, `UNSUPPORTED`, `READ_FAILED`, `LOCK_FAILED`, `TIMEOUT`, `NOT_AVAILABLE`.
class TagIoException implements Exception {
  const TagIoException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => 'TagIoException($code${message == null ? '' : ': $message'})';
}

/// Writing card tags (S20, Android): the hardware half of `CardProgrammer`.
abstract interface class TagWriter {
  /// Tags held to the phone while the writer is on.
  Stream<NfcWriterTag> get tags;

  /// On: every tag goes to [tags] and is kept for the operations below; card reading is paused.
  Future<void> setEnabled({required bool enabled});

  Future<TagInfo> inspect();

  Future<void> writeUrl(String url);

  /// A fresh read from the chip.
  Future<NfcTagRead> readBack();

  Future<void> lock();
}

class PlatformTagWriter implements TagWriter {
  PlatformTagWriter({required NfcService nfc, MethodChannel channel = WaiterChannels.nfc})
    : _nfc = nfc,
      _channel = channel;

  final NfcService _nfc;
  final MethodChannel _channel;

  /// One tag operation may not take longer (a tag half off the antenna can stall the stack).
  static const Duration operationTimeout = Duration(seconds: 10);

  @override
  Stream<NfcWriterTag> get tags => _nfc.events.where((NfcEvent e) => e is NfcWriterTag).cast<NfcWriterTag>();

  @override
  Future<void> setEnabled({required bool enabled}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    await _invoke<void>('writerMode', <String, Object?>{'enabled': enabled});
  }

  @override
  Future<TagInfo> inspect() async {
    final Map<Object?, Object?>? m = await _invoke<Map<Object?, Object?>>('writerInspect');
    if (m == null) throw const TagIoException('READ_FAILED');
    final Object? type = m['type'];
    final Object? size = m['maxSize'];
    return TagInfo(
      uid: m['uid'] is String ? m['uid']! as String : '',
      type: type is String ? type : null,
      writable: m['writable'] == true,
      maxSize: size is int ? size : -1,
    );
  }

  @override
  Future<void> writeUrl(String url) => _invoke<void>('writerWrite', <String, Object?>{'url': url});

  @override
  Future<NfcTagRead> readBack() async {
    final Map<Object?, Object?>? m = await _invoke<Map<Object?, Object?>>('writerRead');
    final Object? uid = m?['uid'];
    if (uid is! String || uid.isEmpty) throw const TagIoException('READ_FAILED');
    final Object? url = m?['url'];
    return NfcTagRead(uid: uid, url: url is String && url.isNotEmpty ? url : null);
  }

  @override
  Future<void> lock() => _invoke<void>('writerLock');

  Future<T?> _invoke<T>(String method, [Map<String, Object?>? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments).timeout(operationTimeout);
    } on TimeoutException {
      throw const TagIoException('TIMEOUT');
    } on PlatformException catch (e) {
      throw TagIoException(e.code, e.message);
    } on MissingPluginException {
      throw const TagIoException('NOT_AVAILABLE');
    }
  }
}
