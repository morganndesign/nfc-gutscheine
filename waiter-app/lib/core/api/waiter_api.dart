import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../cards/ntag424_session.dart';
import 'api_client.dart';
import 'api_failure.dart';
import 'models.dart';

/// The QR text of a printable or digital voucher: `GCPV1.` + 32 random bytes
/// in base64url. Anything else is not sent to the server.
final RegExp voucherQrPattern = RegExp(r'^GCPV1\.[A-Za-z0-9_-]{43}$');

/// The endpoints of the waiter app. Nothing else is ever called.
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

  /// The account's language (`de`, `en`, `bs`), the same in the dashboard.
  Future<void> setLanguage(String code) =>
      _client.send('PUT', '/auth/language', body: <String, Object?>{'locale': code});

  /// The restaurant's logo (PNG) from its versioned path in the settings.
  Future<Uint8List> logo(String path) => _client.bytes(path.replaceFirst(RegExp(r'^/api/v1'), ''));

  Future<CurrentDevice> currentDevice() async =>
      CurrentDevice.fromJson((await _client.send('GET', '/devices/current')).json);

  /// Proves that the voucher's QR is here, now: a single-use presentment for
  /// the redemption that follows.
  Future<Presentment> presentQr(String credential, {CancelToken? cancelToken}) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/presentments',
      body: <String, Object?>{'purpose': 'spend', 'method': 'printable_qr', 'credential': credential},
      timeout: ApiTimeouts.lookup,
      cancelToken: cancelToken,
    );
    return _parse(r, Presentment.fromJson);
  }

  /// A card, step 1: what the phone read from it and the card's challenge.
  Future<CardChallenge> beginCardPresentment(CardTap tap, {String purpose = 'spend', CancelToken? cancelToken}) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/presentments/cards',
      body: <String, Object?>{
        'purpose': purpose,
        'tap_url': tap.tapUrl,
        'rf_uid': tap.rfUidHex,
        'challenge': tap.challengeHex,
      },
      timeout: ApiTimeouts.lookup,
      cancelToken: cancelToken,
    );
    return _parse(r, CardChallenge.fromJson);
  }

  /// A card, step 2: its answer to the relayed command. Returns the presentment, as a scan does.
  Future<Presentment> completeCardPresentment(
    String authentication,
    String responseHex, {
    CancelToken? cancelToken,
  }) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/presentments/cards/$authentication',
      body: <String, Object?>{'response': responseHex},
      timeout: ApiTimeouts.lookup,
      cancelToken: cancelToken,
    );
    return _parse(r, Presentment.fromJson);
  }

  /// A card, step 2, for binding or receiving: the card is proven, no voucher yet.
  Future<CardPresented> completeCardPresentmentForCard(String authentication, String responseHex) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/presentments/cards/$authentication',
      body: <String, Object?>{'response': responseHex},
      timeout: ApiTimeouts.lookup,
    );
    return _parse(r, CardPresented.fromJson);
  }

  Future<List<CardBatchSummary>> cardBatches() async =>
      _parse(await _client.send('GET', '/card-batches'), CardBatchSummary.listFromJson);

  /// Delivery receipt: the counted quantity and one tapped card of the batch. Answers the batch's new status.
  Future<String> receiveCardBatch(String batchId, int count, String presentmentId) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/card-batches/$batchId/receipt',
      body: <String, Object?>{'count': count, 'presentment_id': presentmentId},
    );
    return _parse(r, (Map<String, Object?> json) {
      final Object? data = json['data'];
      final Object? status = data is Map ? data['status'] : null;
      if (status is! String) throw const FormatException('status');
      return status;
    });
  }

  Future<CardInfo> card(String number) async =>
      _parse(await _client.send('GET', '/cards/${Uri.encodeComponent(number)}'), CardInfo.fromJson);

  /// `suspend` or `resume`.
  Future<CardInfo> changeCard(String number, String action, String reason) async => _parse(
    await _client.send('POST', '/cards/${Uri.encodeComponent(number)}/$action', body: <String, Object?>{'reason': reason}),
    CardInfo.fromJson,
  );

  /// Moves the voucher of card [number] to the tapped stock card; answers the new card.
  /// [surrenderPresentmentId]: the old card's `surrender` presentment when it is at hand; without it only an owner
  /// may replace (lost, stolen).
  Future<CardInfo> replaceCard(String number, String presentmentId, String reason, {String? surrenderPresentmentId}) async => _parse(
    await _client.send(
      'POST',
      '/cards/${Uri.encodeComponent(number)}/replacement',
      body: <String, Object?>{
        'presentment_id': presentmentId,
        'surrender_presentment_id': ?surrenderPresentmentId,
        'reason': reason,
      },
    ),
    CardInfo.fromJson,
  );

  /// Station: the batches waiting for personalisation.
  Future<List<StationBatch>> stationBatches() async {
    final ApiResponse r = await _client.send('GET', '/admin/station/batches');
    return _parse(r, StationBatch.listFromJson);
  }

  /// Station, first round for a chip on the phone (its radio UID).
  Future<PersonalizationRound> beginPersonalization(String batchId, String rfUidHex) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/admin/card-batches/$batchId/personalizations',
      body: <String, Object?>{'rf_uid': rfUidHex},
      timeout: ApiTimeouts.lookup,
    );
    return _parse(r, PersonalizationRound.fromJson);
  }

  /// Station, next round: the chip's answers to the last round's commands.
  Future<PersonalizationRound> continuePersonalization(String id, List<String> responsesHex) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/admin/personalizations/$id',
      body: <String, Object?>{'responses': responsesHex},
      timeout: ApiTimeouts.lookup,
    );
    return _parse(r, PersonalizationRound.fromJson);
  }

  /// One redemption attempt. The same [idempotencyKey] on a retry replays the
  /// booking instead of making a second one.
  Future<RedeemResult> redeem({
    required String voucherId,
    required int amount,
    required String presentmentId,
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/vouchers/$voucherId/redemptions',
      body: <String, Object?>{'amount': amount, 'presentment_id': presentmentId},
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
      timeout: ApiTimeouts.redeemAttempt,
      cancelToken: cancelToken,
    );
    return _parse(r, (Map<String, Object?> json) => RedeemResult.fromJson(json, requestId: r.requestId));
  }

  /// Asks whether one of this user's attempts was booked, without sending the
  /// debit again.
  Future<RedemptionOutcome> redemptionOutcome({required String voucherId, required String idempotencyKey}) async {
    final ApiResponse r = await _client.send('GET', '/vouchers/$voucherId/redemptions/$idempotencyKey');
    return _parse(r, (Map<String, Object?> json) => RedemptionOutcome.fromJson(json, requestId: r.requestId));
  }

  /// Sells a printable voucher. The same [idempotencyKey] on a retry replays
  /// the sale (with a fresh QR) instead of selling another.
  Future<SoldVoucher> sell({
    required int value,
    required PaymentInput payment,
    String? customerEmail,
    required String idempotencyKey,
    String? cardPresentmentId,
  }) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/vouchers',
      body: <String, Object?>{
        'value': value,
        'form': cardPresentmentId == null ? 'printable' : 'card',
        'presentment_id': ?cardPresentmentId,
        'payment': payment.toJson(),
        if (customerEmail != null) 'customer': <String, Object?>{'email': customerEmail},
      },
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
    );
    return _parse(r, SoldVoucher.fromJson);
  }

  /// Tops up the guest's card at the till. [presentmentId]: its `reload` tap. The same [idempotencyKey] on a
  /// retry replays the booking instead of making a second one.
  Future<ReloadResult> reload({
    required String voucherId,
    required int amount,
    required PaymentInput payment,
    required String presentmentId,
    required String idempotencyKey,
  }) async {
    final ApiResponse r = await _client.send(
      'POST',
      '/vouchers/$voucherId/reloads',
      body: <String, Object?>{'amount': amount, 'payment': payment.toJson(), 'presentment_id': presentmentId},
      headers: <String, String>{'Idempotency-Key': idempotencyKey},
    );
    return _parse(r, ReloadResult.fromJson);
  }

  /// A 2xx body that does not parse is a server fault (never half a voucher).
  T _parse<T>(ApiResponse r, T Function(Map<String, Object?> json) parse) {
    try {
      return parse(r.json);
    } on FormatException {
      throw ApiServerFault(requestId: r.requestId, status: r.status);
    }
  }
}
