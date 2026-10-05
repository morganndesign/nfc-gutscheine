import 'dart:async';

import '../api/api_failure.dart';
import '../api/models.dart';
import '../api/waiter_api.dart';
import '../platform/nfc_relay.dart';
import 'ntag424_session.dart';

/// Why a card could not be presented.
enum CardPresentFailure {
  /// The iPhone sheet was closed, or the reader stopped before a card came.
  cancelled,

  /// NFC is switched off (Android).
  nfcOff,

  /// This phone cannot read cards.
  unsupported,

  /// The card left the phone during the exchange.
  moved,

  /// Not a card of this restaurant, a copied tap, or a chip without the card's keys.
  notRecognized,

  /// The card's live check failed (CARD_AUTHENTICATION_FAILED, e.g. moved too early): hold it again.
  unverified,

  /// A genuine card of this restaurant in the wrong state for this purpose ([CardPresentException.cardState]).
  notUsable,

  /// Too many failed attempts from this phone; wait.
  throttled,

  network,
  server,

  /// The sign-in may not do this (the session is handled by the caller).
  forbidden,
}

class CardPresentException implements Exception {
  const CardPresentException(this.failure, {this.cardState, this.requestId, this.api});

  final CardPresentFailure failure;

  /// For [CardPresentFailure.notUsable]: the card's state, or the reason (`other_restaurant`, a refused
  /// presentment's `card_not_active` / `card_state`, [otherCard]).
  final String? cardState;

  /// A tap to confirm an entry found another card than the one it was made for.
  static const String otherCard = 'other_card';
  final String? requestId;

  /// The API failure behind it, for the session (401, device revoked).
  final ApiFailure? api;

  @override
  String toString() => 'CardPresentException(${failure.name})';
}

/// A card held to the phone — `bind` (sale, replacement), `receive` (delivery), `surrender` or `reload`: the phone
/// reads the card's URL, starts AuthenticateEV2First with K3 and relays the server's challenge. The server answers with a single-use, 60-second presentment. Android and iPhone alike; the phone
/// never holds a key.
class CardPresenter {
  CardPresenter({required WaiterApi api, required NfcRelay nfc}) : _api = api, _nfc = nfc;

  final WaiterApi _api;
  final NfcRelay _nfc;

  /// [onDetected] runs when a card is on the phone (the screen switches to "checking"). A `reload` tap of a guest's
  /// card carries its voucher ([CardPresented.voucher]).
  Future<CardPresented> present(
    String purpose, {
    required ({String prompt, String checking, String done, String failed}) texts,
    void Function()? onDetected,
  }) async {
    CardLink? card;
    try {
      card = await _nfc.start(prompt: texts.prompt);
      onDetected?.call();
      final CardLink link = card;
      // Once a card is on the phone the exchange ends — with a result or a message — never an endless spinner.
      final CardPresented presented = await () async {
        final CardTap tap = await Ntag424Session.read(link);
        final CardChallenge challenge = await _api.beginCardPresentment(tap, purpose: purpose);
        final String answer = await Ntag424Session.answer(link, challenge.commandHex);
        return _api.completeCardPresentmentForCard(challenge.authentication, answer);
      }().timeout(exchangeTimeout);
      await card.close(message: texts.done);
      return presented;
    } on TimeoutException {
      await _closeQuietly(card, texts.failed);
      throw const CardPresentException(CardPresentFailure.moved);
    } on NfcRelayException catch (e) {
      await card?.close(message: texts.failed, failed: true);
      throw CardPresentException(switch (e.failure) {
        NfcFailure.cancelled || NfcFailure.timeout || NfcFailure.busy => CardPresentFailure.cancelled,
        NfcFailure.disabled => CardPresentFailure.nfcOff,
        NfcFailure.unsupported => CardPresentFailure.unsupported,
        NfcFailure.tagLost || NfcFailure.io => CardPresentFailure.moved,
      });
    } on CardProtocolException {
      await card?.close(message: texts.failed, failed: true);
      throw const CardPresentException(CardPresentFailure.notRecognized);
    } on ApiFailure catch (e) {
      await card?.close(message: texts.failed, failed: true);
      throw CardPresentException(
        switch (e) {
          ApiRejected(code: 'CARD_NOT_USABLE') => CardPresentFailure.notUsable,
          ApiRejected(code: 'CARD_AUTHENTICATION_FAILED') => CardPresentFailure.unverified,
          ApiRejected(:final int status) when status == 429 => CardPresentFailure.throttled,
          ApiRejected(:final int status) when status == 403 && e.code == 'FORBIDDEN' => CardPresentFailure.forbidden,
          ApiRejected(:final int status) when status < 500 => CardPresentFailure.notRecognized,
          ApiTransportFailure() => CardPresentFailure.network,
          ApiUnauthorized() => CardPresentFailure.forbidden,
          _ => CardPresentFailure.server,
        },
        cardState: e is ApiRejected ? (e.contextString('state') ?? e.contextString('reason')) : null,
        requestId: e.requestId,
        api: e,
      );
    } on CardPresentException {
      rethrow;
    } on Object {
      // Anything else a strange tag provokes (a blank card, another chip): not a card of this restaurant.
      await _closeQuietly(card, texts.failed);
      throw const CardPresentException(CardPresentFailure.notRecognized);
    }
  }

  /// Upper bound for one exchange after the card was detected (card commands and two server calls).
  static const Duration exchangeTimeout = Duration(seconds: 20);

  static Future<void> _closeQuietly(CardLink? card, String message) async {
    try {
      await card?.close(message: message, failed: true);
    } on Object {
      // The card session is already gone.
    }
  }

  /// Stops a reader that is still waiting for a card (leaving the screen).
  Future<void> cancel() => _nfc.cancel();
}
