import Flutter
import LocalAuthentication
import UIKit

/// Device facts, the app's settings page and the biometric enrolment
/// fingerprint (09 §7.5, §7.6) behind the channel `giftcard_waiter/system`.
final class WaiterSystem {
  private static let channelName = "giftcard_waiter/system"

  private let channel: FlutterMethodChannel

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
    switch call.method {
    case "deviceFacts":
      result(deviceFacts())
    case "openAppSettings":
      openAppSettings()
      result(nil)
    case "biometricEnrollment":
      result(biometricEnrollment())
    case "resetBiometricEnrollment":
      // The evaluated policy domain state needs no reset on iOS.
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Device facts

  private func deviceFacts() -> [String: Any] {
    let device = UIDevice.current
    return [
      "platform": "ios",
      "osVersion": device.systemVersion,
      "model": Self.marketingName(for: Self.machineIdentifier()) ?? device.model,
      "isTablet": device.userInterfaceIdiom == .pad,
    ]
  }

  /// `iPhone15,4` etc.; the simulator reports the simulated device.
  private static func machineIdentifier() -> String {
    if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
      return simulated
    }
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafeBytes(of: &systemInfo.machine) { buffer in
      String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
    }
  }

  private static func marketingName(for identifier: String) -> String? {
    modelNames[identifier]
  }

  /// Devices that run iOS/iPadOS 16 or later (09 §11.3 minimum).
  private static let modelNames: [String: String] = [
    // iPhone 8 / X (iOS 16 only)
    "iPhone10,1": "iPhone 8", "iPhone10,4": "iPhone 8",
    "iPhone10,2": "iPhone 8 Plus", "iPhone10,5": "iPhone 8 Plus",
    "iPhone10,3": "iPhone X", "iPhone10,6": "iPhone X",
    // iPhone XS / XR
    "iPhone11,2": "iPhone XS",
    "iPhone11,4": "iPhone XS Max", "iPhone11,6": "iPhone XS Max",
    "iPhone11,8": "iPhone XR",
    // iPhone 11
    "iPhone12,1": "iPhone 11",
    "iPhone12,3": "iPhone 11 Pro",
    "iPhone12,5": "iPhone 11 Pro Max",
    "iPhone12,8": "iPhone SE (2nd generation)",
    // iPhone 12
    "iPhone13,1": "iPhone 12 mini",
    "iPhone13,2": "iPhone 12",
    "iPhone13,3": "iPhone 12 Pro",
    "iPhone13,4": "iPhone 12 Pro Max",
    // iPhone 13 / 14 (non-Pro) / SE 3
    "iPhone14,4": "iPhone 13 mini",
    "iPhone14,5": "iPhone 13",
    "iPhone14,2": "iPhone 13 Pro",
    "iPhone14,3": "iPhone 13 Pro Max",
    "iPhone14,6": "iPhone SE (3rd generation)",
    "iPhone14,7": "iPhone 14",
    "iPhone14,8": "iPhone 14 Plus",
    // iPhone 14 Pro / 15
    "iPhone15,2": "iPhone 14 Pro",
    "iPhone15,3": "iPhone 14 Pro Max",
    "iPhone15,4": "iPhone 15",
    "iPhone15,5": "iPhone 15 Plus",
    "iPhone16,1": "iPhone 15 Pro",
    "iPhone16,2": "iPhone 15 Pro Max",
    // iPhone 16
    "iPhone17,1": "iPhone 16 Pro",
    "iPhone17,2": "iPhone 16 Pro Max",
    "iPhone17,3": "iPhone 16",
    "iPhone17,4": "iPhone 16 Plus",
    "iPhone17,5": "iPhone 16e",
    // iPhone 17
    "iPhone18,1": "iPhone 17 Pro",
    "iPhone18,2": "iPhone 17 Pro Max",
    "iPhone18,3": "iPhone 17",
    "iPhone18,4": "iPhone Air",
    // iPad
    "iPad12,1": "iPad (9th generation)", "iPad12,2": "iPad (9th generation)",
    "iPad13,18": "iPad (10th generation)", "iPad13,19": "iPad (10th generation)",
    "iPad15,7": "iPad (A16)", "iPad15,8": "iPad (A16)",
    // iPad mini
    "iPad14,1": "iPad mini (6th generation)", "iPad14,2": "iPad mini (6th generation)",
    "iPad16,1": "iPad mini (A17 Pro)", "iPad16,2": "iPad mini (A17 Pro)",
    // iPad Air
    "iPad13,1": "iPad Air (4th generation)", "iPad13,2": "iPad Air (4th generation)",
    "iPad13,16": "iPad Air (5th generation)", "iPad13,17": "iPad Air (5th generation)",
    "iPad14,8": "iPad Air 11-inch (M2)", "iPad14,9": "iPad Air 11-inch (M2)",
    "iPad14,10": "iPad Air 13-inch (M2)", "iPad14,11": "iPad Air 13-inch (M2)",
    "iPad15,3": "iPad Air 11-inch (M3)", "iPad15,4": "iPad Air 11-inch (M3)",
    "iPad15,5": "iPad Air 13-inch (M3)", "iPad15,6": "iPad Air 13-inch (M3)",
    // iPad Pro
    "iPad13,4": "iPad Pro 11-inch (3rd generation)", "iPad13,5": "iPad Pro 11-inch (3rd generation)",
    "iPad13,6": "iPad Pro 11-inch (3rd generation)", "iPad13,7": "iPad Pro 11-inch (3rd generation)",
    "iPad13,8": "iPad Pro 12.9-inch (5th generation)", "iPad13,9": "iPad Pro 12.9-inch (5th generation)",
    "iPad13,10": "iPad Pro 12.9-inch (5th generation)", "iPad13,11": "iPad Pro 12.9-inch (5th generation)",
    "iPad14,3": "iPad Pro 11-inch (4th generation)", "iPad14,4": "iPad Pro 11-inch (4th generation)",
    "iPad14,5": "iPad Pro 12.9-inch (6th generation)", "iPad14,6": "iPad Pro 12.9-inch (6th generation)",
    "iPad16,3": "iPad Pro 11-inch (M4)", "iPad16,4": "iPad Pro 11-inch (M4)",
    "iPad16,5": "iPad Pro 13-inch (M4)", "iPad16,6": "iPad Pro 13-inch (M4)",
  ]

  // MARK: - Settings

  private func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }

  // MARK: - Biometric enrolment (09 §7.5)

  /// Base64 of the evaluated policy domain state; it changes when a face or
  /// finger is added or removed. Nil when no biometrics are enrolled. During a
  /// biometry lockout the state is still reported, so a lockout is not
  /// mistaken for an enrolment change.
  private func biometricEnrollment() -> String? {
    let context = LAContext()
    var error: NSError?
    let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    let lockedOut = (error as? LAError)?.code == .biometryLockout
    guard canEvaluate || lockedOut, let state = context.evaluatedPolicyDomainState else {
      return nil
    }
    return state.base64EncodedString()
  }
}
