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

  /// For [CardPresentFailure.notUsable]: the card's state, or the reason (`other_restaurant`).
  final String? cardState;
  final String? requestId;

  /// The API failure behind it, for the session (401, device revoked).
  final ApiFailure? api;

  @override
  String toString() => 'CardPresentException(${failure.name})';
}

/// A card held to the phone — `bind` (sale, replacement), `receive` (delivery), `surrender` or `reload`: the phone reads the card's URL, starts AuthenticateEV2First with K3 and relays the server's
/// challenge. The server answers with a single-use, 60-second presentment. Android and iPhone alike; the phone
/// never holds a key.
class CardPresenter {
  CardPresenter({required WaiterApi api, required NfcRelay nfc}) : _api = api, _nfc = nfc;

  final WaiterApi _api;
  final NfcRelay _nfc;

  /// [onDetected] runs when a card is on the phone (the screen switches to "checking").
  Future<CardPresented> present(
    String purpose, {
    required ({String prompt, String checking, String done, String failed}) texts,
    void Function()? onDetected,
  }) => _present(purpose, texts, onDetected, _api.completeCardPresentmentForCard);

  /// A guest's card for a purpose that names its voucher (`reload`): the presentment carries the voucher.
  Future<Presentment> presentVoucher(
    String purpose, {
    required ({String prompt, String checking, String done, String failed}) texts,
    void Function()? onDetected,
  }) => _present(purpose, texts, onDetected, _api.completeCardPresentment);

  Future<T> _present<T>(
    String purpose,
    ({String prompt, String checking, String done, String failed}) texts,
    void Function()? onDetected,
    Future<T> Function(String authentication, String answer) complete,
  ) async {
    CardLink? card;
    try {
      card = await _nfc.start(prompt: texts.prompt);
      onDetected?.call();
      final CardTap tap = await Ntag424Session.read(card);
      final CardChallenge challenge = await _api.beginCardPresentment(tap, purpose: purpose);
      final String answer = await Ntag424Session.answer(card, challenge.commandHex);
      final T presented = await complete(challenge.authentication, answer);
      await card.close(message: texts.done);
      return presented;
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
    }
  }

  /// Stops a reader that is still waiting for a card (leaving the screen).
  Future<void> cancel() => _nfc.cancel();
}
