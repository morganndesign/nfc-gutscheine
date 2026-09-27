import CoreNFC
import Flutter
import UIKit

/// iPhone card reading (09 §7.2, 03a §6.2) behind the channels
/// `giftcard_waiter/nfc` and `giftcard_waiter/nfc/events`.
///
/// One `NFCTagReaderSession` (ISO 14443: MIFARE family for NTAG21x, ISO 7816
/// via the NDEF application identifier for NTAG 424 DNA) per user action. The
/// session delegate runs on the main queue, so all state here is main-thread
/// only and events reach Flutter on the main thread.
final class WaiterNfc: NSObject, FlutterStreamHandler, NFCTagReaderSessionDelegate {
  private static let methodChannelName = "giftcard_waiter/nfc"
  private static let eventChannelName = "giftcard_waiter/nfc/events"

  /// 03a §6.2 timings.
  private static let multipleTagsRestartDelay: TimeInterval = 0.5
  private static let readFailedRestartDelay: TimeInterval = 0.4
  private static let notCardRestartDelay: TimeInterval = 1.0
  private static let timeoutWarningDelay: TimeInterval = 45

  private static let maxBufferedEvents = 8

  private struct SheetTexts {
    var alert = ""
    var found = ""
    var multiple = ""
    var readFailed = ""
    var timeoutSoon = ""
    var notCard = ""
  }

  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?
  private var pendingEvents: [[String: Any]] = []

  /// The session the app currently owns. Set to nil as soon as the app ends
  /// it itself (finishSession), so its later invalidation reports nothing.
  private var session: NFCTagReaderSession?
  private var texts = SheetTexts()
  /// A tag was sent to Dart; waiting for finishSession / rejectTag.
  private var awaitingDecision = false
  private var timeoutWarning: DispatchWorkItem?

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(name: Self.methodChannelName, binaryMessenger: messenger)
    eventChannel = FlutterEventChannel(name: Self.eventChannelName, binaryMessenger: messenger)
    super.init()
    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result: result)
    }
    eventChannel.setStreamHandler(self)
  }

  // MARK: - Method channel

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(NFCTagReaderSession.readingAvailable ? "enabled" : "unsupported")
    case "startSession":
      startSession(arguments: call.arguments as? [String: Any] ?? [:])
      result(nil)
    case "finishSession":
      finishSession()
      result(nil)
    case "rejectTag":
      rejectTag()
      result(nil)
    case "readerMode", "openSettings":
      // Android only; the iPhone reads through the system sheet.
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startSession(arguments: [String: Any]) {
    texts = SheetTexts(
      alert: arguments["alert"] as? String ?? "",
      found: arguments["found"] as? String ?? "",
      multiple: arguments["multiple"] as? String ?? "",
      readFailed: arguments["readFailed"] as? String ?? "",
      timeoutSoon: arguments["timeoutSoon"] as? String ?? "",
      notCard: arguments["notCard"] as? String ?? ""
    )

    if let running = session {
      // "Scan card" is disabled while a session is active; keep the sheet.
      running.alertMessage = texts.alert
      return
    }

    // ISO 14443 polling; the ISO 7816 NDEF application (D2760000850101) listed in
    // Info.plist lets NTAG 424 DNA surface as `.iso7816` as well (13 Q9).
    let created: NFCTagReaderSession? = NFCTagReaderSession.readingAvailable
      ? NFCTagReaderSession(pollingOption: [.iso14443], delegate: self, queue: .main)
      : nil
    guard let newSession = created else {
      emit(["type": "sessionEnded", "reason": "unavailable"])
      return
    }

    newSession.alertMessage = texts.alert
    session = newSession
    awaitingDecision = false
    newSession.begin()
    scheduleTimeoutWarning(for: newSession)
  }

  /// Dart accepted the card: show `ios.sheet.found` and close the sheet (system ✓).
  private func finishSession() {
    guard let current = session else { return }
    cancelTimeoutWarning()
    session = nil
    awaitingDecision = false
    current.alertMessage = texts.found
    current.invalidate()
  }

  /// Not a gift card: `scan.notCard`, keep the sheet, poll again after 1 s.
  private func rejectTag() {
    guard let current = session else { return }
    awaitingDecision = false
    current.alertMessage = texts.notCard
    restartPolling(current, after: Self.notCardRestartDelay)
  }

  // MARK: - Event channel

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    let buffered = pendingEvents
    pendingEvents.removeAll()
    buffered.forEach { events($0) }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func emit(_ event: [String: Any]) {
    if let sink = eventSink {
      sink(event)
      return
    }
    if pendingEvents.count >= Self.maxBufferedEvents {
      pendingEvents.removeFirst()
    }
    pendingEvents.append(event)
  }

  // MARK: - NFCTagReaderSessionDelegate (main queue)

  func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

  func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    // A session the app already finished (or replaced) reports nothing.
    guard session === self.session else { return }
    self.session = nil
    awaitingDecision = false
    cancelTimeoutWarning()
    emit(["type": "sessionEnded", "reason": Self.endReason(for: error)])
  }

  func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    guard session === self.session, !awaitingDecision else { return }

    if tags.count > 1 {
      session.alertMessage = texts.multiple
      restartPolling(session, after: Self.multipleTagsRestartDelay)
      return
    }
    guard let tag = tags.first else {
      restartPolling(session, after: Self.readFailedRestartDelay)
      return
    }

    let identifier: Data
    let ndefTag: NFCNDEFTag
    switch tag {
    case let .miFare(miFareTag):
      identifier = miFareTag.identifier
      ndefTag = miFareTag
    case let .iso7816(iso7816Tag):
      identifier = iso7816Tag.identifier
      ndefTag = iso7816Tag
    case .feliCa, .iso15693:
      // Not polled (ISO 14443 only); never a gift card.
      session.alertMessage = texts.notCard
      restartPolling(session, after: Self.notCardRestartDelay)
      return
    @unknown default:
      session.alertMessage = texts.notCard
      restartPolling(session, after: Self.notCardRestartDelay)
      return
    }

    session.connect(to: tag) { [weak self] error in
      guard let self, session === self.session else { return }
      if error != nil {
        self.readFailed(session)
        return
      }
      self.readNdef(ndefTag, uid: Self.formatUid(identifier), session: session)
    }
  }

  // MARK: - Reading

  private func readNdef(_ tag: NFCNDEFTag, uid: String, session: NFCTagReaderSession) {
    tag.queryNDEFStatus { [weak self] status, _, error in
      guard let self, session === self.session else { return }
      if error != nil {
        self.readFailed(session)
        return
      }
      if status == .notSupported {
        // Not NDEF formatted (bank or transit card): Dart answers with rejectTag.
        self.deliverTag(uid: uid, url: nil)
        return
      }
      tag.readNDEF { [weak self] message, error in
        guard let self, session === self.session else { return }
        if let error {
          if Self.isEmptyMessage(error) {
            self.deliverTag(uid: uid, url: nil)
          } else {
            self.readFailed(session)
          }
          return
        }
        self.deliverTag(uid: uid, url: message.flatMap(Self.firstUri))
      }
    }
  }

  private func deliverTag(uid: String, url: String?) {
    awaitingDecision = true
    var event: [String: Any] = ["type": "tag", "uid": uid]
    if let url {
      event["url"] = url
    }
    emit(event)
  }

  /// I/O error or tag lost: `ios.sheet.readFailed`, keep the sheet, poll again after 400 ms.
  private func readFailed(_ session: NFCTagReaderSession) {
    session.alertMessage = texts.readFailed
    restartPolling(session, after: Self.readFailedRestartDelay)
  }

  private func restartPolling(_ target: NFCTagReaderSession, after delay: TimeInterval) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
      guard let self, target === self.session, !self.awaitingDecision, target.isReady else { return }
      target.restartPolling()
    }
  }

  // MARK: - Timeout warning

  /// 45 s without an accepted card (15 s before the system timeout): `ios.sheet.timeoutSoon`.
  private func scheduleTimeoutWarning(for target: NFCTagReaderSession) {
    cancelTimeoutWarning()
    let work = DispatchWorkItem { [weak self] in
      guard let self, target === self.session, !self.awaitingDecision else { return }
      target.alertMessage = self.texts.timeoutSoon
    }
    timeoutWarning = work
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.timeoutWarningDelay, execute: work)
  }

  private func cancelTimeoutWarning() {
    timeoutWarning?.cancel()
    timeoutWarning = nil
  }

  // MARK: - Helpers

  /// `04:A2:3F:1B:6C:80:12` — upper-case hex bytes joined by colons.
  private static func formatUid(_ identifier: Data) -> String {
    identifier.map { String(format: "%02X", $0) }.joined(separator: ":")
  }

  /// First well-known URI record, else the first absolute-URI record.
  private static func firstUri(_ message: NFCNDEFMessage) -> String? {
    for record in message.records {
      if record.typeNameFormat == .nfcWellKnown, let url = record.wellKnownTypeURIPayload() {
        return url.absoluteString
      }
      if record.typeNameFormat == .absoluteURI,
         let text = String(data: record.type, encoding: .utf8),
         let url = URL(string: text) {
        return url.absoluteString
      }
    }
    return nil
  }

  private static func isEmptyMessage(_ error: Error) -> Bool {
    (error as? NFCReaderError)?.code == .ndefReaderSessionErrorZeroLengthMessage
  }

  private static func endReason(for error: Error) -> String {
    guard let readerError = error as? NFCReaderError else { return "unavailable" }
    switch readerError.code {
    case .readerSessionInvalidationErrorUserCanceled:
      return "userCancel"
    case .readerSessionInvalidationErrorSessionTimeout:
      return "timeout"
    case .readerSessionInvalidationErrorSystemIsBusy:
      return "busy"
    default:
      return "unavailable"
    }
  }
}
