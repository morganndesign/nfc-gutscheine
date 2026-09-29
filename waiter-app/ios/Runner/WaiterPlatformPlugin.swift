import Flutter
import UIKit

/// The app's own platform channels (09 §7, §8): feedback, system and the NTAG 424 relay.
/// Registered from `AppDelegate.didInitializeImplicitFlutterEngine`.
final class WaiterPlatformPlugin: NSObject, FlutterPlugin {
  private let feedback: WaiterFeedback
  private let system: WaiterSystem
  private let nfc: WaiterNfc

  private init(messenger: FlutterBinaryMessenger) {
    feedback = WaiterFeedback(messenger: messenger)
    system = WaiterSystem(messenger: messenger)
    nfc = WaiterNfc(messenger: messenger)
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = WaiterPlatformPlugin(messenger: registrar.messenger())
    // The registrar keeps the published instance (and with it the channel handlers) alive.
    registrar.publish(plugin)
  }
}
