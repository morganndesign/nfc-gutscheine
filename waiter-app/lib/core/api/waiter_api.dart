import 'package:dio/dio.dart';

import 'api_client.dart';
import 'api_failure.dart';
import 'models.dart';

/// How a card was read (`method` of `POST /scan`, 09 §9.2).
enum ScanMethod { nfc, qr, link, manual }

/// A lookup request. Built once per read; a SUN-signed URL is never sent twice
/// (03b §1.2).
class ScanRequest {
  const ScanRequest.nfc({required String url, required String uid, this.isSunSigned = false})
      : method = ScanMethod.nfc,
        token = url,
        nfcUid = uid,
        cardNumber = null;

  const ScanRequest.qr({required String url, this.isSunSigned = false})
      : method = ScanMethod.qr,
        token = url,
        nfcUid = null,
        cardNumber = null;

  const ScanRequest.link({required String url, this.isSunSigned = false})
      : method = ScanMethod.link,
        token = url,
        nfcUid = null,
        cardNumber = null;

  const ScanRequest.manual({required String digits})
      : method = ScanMethod.manual,
        token = null,
        nfcUid = null,
        cardNumber = digits,
        isSunSigned = false;

  final ScanMethod method;
  final String? token;
  final String? nfcUid;
  final String? cardNumber;
  final bool isSunSigned;

  Map<String, Object?> toJson() => <String, Object?>{
        'method': method.name,
        if (token != null) 'token': token,
        if (nfcUid != null) 'nfc_uid': nfcUid,
        if (cardNumber != null) 'card_number': cardNumber,
      };
}

/// The endpoints of the waiter app (09 §9.2). Nothing else is ever called.
class WaiterApi {
  WaiterApi(this._client);

  final ApiClient _client;

  Future<AppConfigData> appConfig({required String platform, required String version}) async {
    final ApiResponse r = await _client.send(
      'GET',
      '/app/config',
      query: <String, String>{'platform': platform, 'version': version},
      timeout: ApiTimeouts.config,
      authenticated: false,
    );
    return AppConfigData.fromJson(r.json);
  }

  Future<SignInResult> signIn({
    required String email,
    required String password,
    required String deviceId,
    required String deviceName,
    required String platform,
  }) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/auth/token',
      body: <String, Object?>{
        'email': email,
        'password': password,
        'device_id': deviceId,
        'device_name': deviceName,
        'platform': platform,
      },
      authenticated: false,
    );
    return _parse(r, SignInResult.fromJson);
  }

  Future<SessionUser> me() async {
    final ApiResponse r = await _client.send('GET', '/auth/me');
    return _parse(r, (Map<String, Object?> json) {
      final Object? data = json['data'];
      if (data is! Map) throw const FormatException('Expected "data".');
      return SessionUser.fromJson(data.cast<String, Object?>());
    });
  }

  Future<void> signOut() => _client.send('POST', '/auth/logout');

  Future<CurrentDevice> currentDevice() async =>
      CurrentDevice.fromJson((await _client.send('GET', '/devices/current')).json);

  Future<ScannedCard> scan(ScanRequest request, {CancelToken? cancelToken}) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/scan',
      body: request.toJson(),
      timeout: ApiTimeouts.lookup,
      cancelToken: cancelToken,
    );
    return _parse(r, (Map<String, Object?> json) {
      final Object? data = json['data'];
      if (data is! Map) throw const FormatException('Expected "data".');
      return ScannedCard.fromJson(data.cast<String, Object?>());
    });
  }

  /// One redeem attempt. The app sends no `reference`/`note` in v1 (K4).
  Future<RedeemResult> redeem({
    required String cardId,
    required int amount,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/cards/$cardId/redeem',
      body: <String, Object?>{'amount': amount},
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      timeout: ApiTimeouts.redeemAttempt,
      cancelToken: cancelToken,
    );
    return _parse(r, (Map<String, Object?> json) => RedeemResult.fromJson(json, requestId: r.requestId));
  }

  /// A 2xx body that does not parse is a server fault (never a half-rendered card).
  T _parse<T>(ApiResponse r, T Function(Map<String, Object?> json) parse) {
    try {
      return parse(r.json);
    } on FormatException {
      throw ApiServerFault(requestId: r.requestId, status: r.status);
    }
  }
}
