import Flutter
import UIKit

/// The app's own platform channels (09 §7, §8): feedback and system.
/// Registered from `AppDelegate.didInitializeImplicitFlutterEngine`.
final class WaiterPlatformPlugin: NSObject, FlutterPlugin {
  private let feedback: WaiterFeedback
  private let system: WaiterSystem

  private init(messenger: FlutterBinaryMessenger) {
    feedback = WaiterFeedback(messenger: messenger)
    system = WaiterSystem(messenger: messenger)
    super.init()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let plugin = WaiterPlatformPlugin(messenger: registrar.messenger())
    // The registrar keeps the published instance (and with it the channel handlers) alive.
    registrar.publish(plugin)
  }
}
