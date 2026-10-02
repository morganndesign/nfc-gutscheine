import CoreNFC
import Flutter
import UIKit

/// The NTAG 424 DNA relay (iPhone): it finds an ISO 7816 card with an `NFCTagReaderSession` and forwards
/// command bytes to it and the answers back, nothing else. It holds no key, parses no answer and stores nothing;
/// the server does all cryptography. Channel `giftcard_waiter/nfc`, the same contract as on Android:
///
/// - `availability` → "ready" | "unsupported"
/// - `start` { prompt } → { uid: hex } once a card is on the phone
/// - `transceive` { apdu: bytes } → bytes (data ‖ SW1 SW2)
/// - `stop` { message?, failed? } → ends the system sheet (success or error text)
///
/// Errors: "unsupported", "busy", "cancelled", "timeout", "tag_lost", "io".
final class WaiterNfc: NSObject, NFCTagReaderSessionDelegate {
  private static let channelName = "giftcard_waiter/nfc"

  private let channel: FlutterMethodChannel
  // Touched on the main queue only (method calls and the delegate callbacks, which hop to it).
  private var session: NFCTagReaderSession?
  private var card: Card?
  private var pendingStart: FlutterResult?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "availability":
      result(NFCTagReaderSession.readingAvailable ? "ready" : "unsupported")
    case "start":
      start(prompt: arguments?["prompt"] as? String, result: result)
    case "transceive":
      transceive((arguments?["apdu"] as? FlutterStandardTypedData)?.data, result: result)
    case "stop":
      stop(message: arguments?["message"] as? String, failed: arguments?["failed"] as? Bool ?? false)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func start(prompt: String?, result: @escaping FlutterResult) {
    guard NFCTagReaderSession.readingAvailable else {
      result(FlutterError(code: "unsupported", message: "This iPhone cannot read cards.", details: nil))
      return
    }
    guard session == nil, pendingStart == nil else {
      result(FlutterError(code: "busy", message: "A card session is already open.", details: nil))
      return
    }
    guard let session = NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: nil) else {
      result(FlutterError(code: "unsupported", message: "The card reader is not available.", details: nil))
      return
    }
    pendingStart = result
    self.session = session
    if let prompt { session.alertMessage = prompt }
    session.begin()
  }

  private func transceive(_ data: Data?, result: @escaping FlutterResult) {
    guard let card, let data, let apdu = NFCISO7816APDU(data: data) else {
      result(FlutterError(code: "tag_lost", message: "No card is open.", details: nil))
      return
    }
    card.send(apdu) { response, sw1, sw2, error in
      DispatchQueue.main.async {
        if let error {
          result(FlutterError(code: Self.code(of: error), message: error.localizedDescription, details: nil))
          return
        }
        var answer = response
        answer.append(contentsOf: [sw1, sw2])
        result(FlutterStandardTypedData(bytes: answer))
      }
    }
  }

  private func stop(message: String?, failed: Bool) {
    // A start still waiting for a card ends now: the session's own invalidation arrives later and asynchronously,
    // and must not answer (or block as "busy") the next start.
    if let pending = pendingStart {
      pendingStart = nil
      pending(FlutterError(code: "cancelled", message: "The card session ended.", details: nil))
    }
    guard let session else { return }
    if failed {
      session.invalidate(errorMessage: message ?? "")
    } else {
      if let message { session.alertMessage = message }
      session.invalidate()
    }
    self.session = nil
    card = nil
  }

  // MARK: - NFCTagReaderSessionDelegate

  func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

  func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    guard let first = tags.first, let found = Card(first) else {
      // Not an ISO 7816 card (an old NTAG 21x, a payment card behind a wallet): keep looking.
      session.restartPolling()
      return
    }
    session.connect(to: first) { [weak self] error in
      DispatchQueue.main.async {
        // A session that was stopped meanwhile (the waiter left) never answers the next one's start.
        guard let self, self.session === session else { return }
        if error != nil {
          session.restartPolling()
          return
        }
        self.card = found
        let uid = found.identifier.map { String(format: "%02X", $0) }.joined()
        self.pendingStart?(["uid": uid])
        self.pendingStart = nil
      }
    }
  }

  func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    DispatchQueue.main.async {
      // Only the current session's end answers a waiting start; a stopped one's late invalidation would otherwise
      // cancel the start of the session that replaced it while its sheet stays open.
      guard self.session === session else { return }
      if let pending = self.pendingStart {
        pending(FlutterError(code: Self.code(of: error), message: error.localizedDescription, details: nil))
      }
      self.pendingStart = nil
      self.session = nil
      self.card = nil
    }
  }

  private static func code(of error: Error) -> String {
    guard let nfc = error as? NFCReaderError else { return "io" }
    switch nfc.code {
    case .readerSessionInvalidationErrorUserCanceled:
      return "cancelled"
    case .readerSessionInvalidationErrorSessionTimeout:
      return "timeout"
    case .readerTransceiveErrorTagConnectionLost, .readerTransceiveErrorTagNotConnected,
         .readerTransceiveErrorTagResponseError:
      return "tag_lost"
    case .readerErrorUnsupportedFeature:
      return "unsupported"
    default:
      return "io"
    }
  }
}

/// A card the relay can send ISO 7816 commands to. NTAG 424 DNA is reported as an ISO 7816 tag once its
/// application (Info.plist `select-identifiers`, D2760000850101) was selected; CoreNFC may also report it as a
/// MIFARE tag of the DESFire family, which takes the same commands wrapped by `sendMiFareISO7816Command`.
private enum Card {
  case iso7816(NFCISO7816Tag)
  case desfire(NFCMiFareTag)

  init?(_ tag: NFCTag) {
    switch tag {
    case let .iso7816(card):
      self = .iso7816(card)
    case let .miFare(card) where card.mifareFamily == .desfire:
      self = .desfire(card)
    default:
      return nil
    }
  }

  var identifier: Data {
    switch self {
    case let .iso7816(card): return card.identifier
    case let .desfire(card): return card.identifier
    }
  }

  func send(_ apdu: NFCISO7816APDU, completion: @escaping (Data, UInt8, UInt8, Error?) -> Void) {
    switch self {
    case let .iso7816(card): card.sendCommand(apdu: apdu, completionHandler: completion)
    case let .desfire(card): card.sendMiFareISO7816Command(apdu, completionHandler: completion)
    }
  }
}
