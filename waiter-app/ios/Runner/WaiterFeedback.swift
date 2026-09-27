import AVFoundation
import Flutter
import UIKit

/// Haptics and sounds on iOS (09 §7.8, 11 §4.1, §5.1, §7) behind the channel
/// `giftcard_waiter/feedback`. Dart decides WHAT plays (tokens, Menu switches,
/// spacing rules); this class maps the payload onto UIKit generators and a
/// preloaded player per sound.
final class WaiterFeedback {
  private static let channelName = "giftcard_waiter/feedback"
  private static let soundExtension = "caf"

  private let channel: FlutterMethodChannel

  /// One generator per kind, kept alive so prepare() carries over to the event.
  private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
  private lazy var selectionGenerator = UISelectionFeedbackGenerator()
  private lazy var notificationGenerator = UINotificationFeedbackGenerator()

  private var players: [String: AVAudioPlayer] = [:]
  private weak var playingPlayer: AVAudioPlayer?
  private var audioSessionConfigured = false

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      self.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let arguments = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "preload":
      result(preload(files: arguments["sounds"] as? [String] ?? []))
    case "prepare":
      prepare(arguments)
      result(nil)
    case "haptic":
      play(arguments)
      result(nil)
    case "sound":
      if let file = arguments["file"] as? String {
        playSound(file)
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Haptics

  private enum Generator {
    case impact(UIImpactFeedbackGenerator, intensity: CGFloat)
    case selection(UISelectionFeedbackGenerator)
    case notification(UINotificationFeedbackGenerator, UINotificationFeedbackGenerator.FeedbackType)
  }

  private func generator(for payload: [String: Any]) -> Generator? {
    switch payload["generator"] as? String {
    case "impact":
      let style: UIImpactFeedbackGenerator.FeedbackStyle
      switch payload["style"] as? String {
      case "light": style = .light
      case "rigid": style = .rigid
      default: style = .medium
      }
      let intensity = (payload["intensity"] as? NSNumber)?.doubleValue ?? 1.0
      return .impact(impactGenerator(style), intensity: CGFloat(min(max(intensity, 0), 1)))
    case "selection":
      return .selection(selectionGenerator)
    case "notification":
      let type: UINotificationFeedbackGenerator.FeedbackType
      switch payload["notification"] as? String {
      case "warning": type = .warning
      case "error": type = .error
      default: type = .success
      }
      return .notification(notificationGenerator, type)
    default:
      return nil
    }
  }

  private func impactGenerator(_ style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
    if let existing = impactGenerators[style] {
      return existing
    }
    let created = UIImpactFeedbackGenerator(style: style)
    impactGenerators[style] = created
    return created
  }

  /// Warms up the Taptic Engine for an expected event (≤ 30 ms latency, 11 §4.1).
  private func prepare(_ payload: [String: Any]) {
    switch generator(for: payload) {
    case let .impact(generator, _):
      generator.prepare()
    case let .selection(generator):
      generator.prepare()
    case let .notification(generator, _):
      generator.prepare()
    case nil:
      break
    }
  }

  private func play(_ payload: [String: Any]) {
    // T8: nothing while the app is not in the foreground.
    guard UIApplication.shared.applicationState == .active else { return }
    switch generator(for: payload) {
    case let .impact(generator, intensity):
      generator.impactOccurred(intensity: intensity)
    case let .selection(generator):
      generator.selectionChanged()
    case let .notification(generator, type):
      generator.notificationOccurred(type)
    case nil:
      break
    }
  }

  // MARK: - Sounds

  /// Ambient category: obeys the silent switch, mixes with other audio and does
  /// not duck it (09 §7.8, 11 §7.1).
  private func configureAudioSession() {
    guard !audioSessionConfigured else { return }
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
      try audioSession.setActive(true)
      audioSessionConfigured = true
    } catch {
      // Without a session the players still follow the default (solo ambient) rules.
    }
  }

  /// Loads every sound once (`Sounds/<file>.caf`). Returns an error for files missing from the bundle.
  private func preload(files: [String]) -> Any? {
    configureAudioSession()
    var missing: [String] = []
    for file in files where players[file] == nil {
      guard let url = Bundle.main.url(forResource: file, withExtension: Self.soundExtension) else {
        missing.append(file)
        continue
      }
      do {
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        players[file] = player
      } catch {
        missing.append(file)
      }
    }
    if missing.isEmpty {
      return nil
    }
    return FlutterError(
      code: "unknown_sound",
      message: "Missing or unreadable bundle sound: \(missing.joined(separator: ", "))",
      details: nil
    )
  }

  private func playSound(_ file: String) {
    guard UIApplication.shared.applicationState == .active, let player = players[file] else { return }
    configureAudioSession()
    // T7: one sound voice at a time — a new sound stops the playing one.
    if let playing = playingPlayer, playing !== player, playing.isPlaying {
      playing.stop()
    }
    player.currentTime = 0
    player.play()
    playingPlayer = player
  }
}
