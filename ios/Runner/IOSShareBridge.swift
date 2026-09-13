import Flutter
import Foundation

extension Notification.Name {
  static let jotCueSharedContentAvailable = Notification.Name(
    "JotCueSharedContentAvailable"
  )
}

/// Drains text queued by the iOS Share Extension. Payloads remain review-first;
/// the bridge never creates Notes, Tasks, or Projects itself.
final class IOSShareBridge {
  static let appGroup = "group.com.tori.pulse.share"
  static let queueKey = "jotcue_pending_shares_v1"

  private let channel: FlutterMethodChannel
  private let defaults: UserDefaults?
  private var observer: NSObjectProtocol?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "com.tori.pulse/share",
      binaryMessenger: messenger
    )
    defaults = UserDefaults(suiteName: Self.appGroup)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "consumePendingShare":
        result(self.consumePending())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    observer = NotificationCenter.default.addObserver(
      forName: .jotCueSharedContentAvailable,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.notifyAvailable()
    }
  }

  private func consumePending() -> [String: String]? {
    guard let defaults else { return nil }
    var queue = defaults.array(forKey: Self.queueKey) as? [[String: String]] ?? []
    guard !queue.isEmpty else { return nil }
    let payload = queue.removeFirst()
    defaults.set(queue, forKey: Self.queueKey)
    return payload
  }

  func notifyAvailable() {
    guard let defaults else { return }
    let queue = defaults.array(forKey: Self.queueKey) as? [[String: String]] ?? []
    guard !queue.isEmpty else { return }
    channel.invokeMethod("sharedContentAvailable", arguments: nil)
  }

  func dispose() {
    channel.setMethodCallHandler(nil)
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
  }
}
