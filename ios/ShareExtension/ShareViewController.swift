import Social
import UniformTypeIdentifiers
import UIKit

/// Minimal text-only handoff. The extension queues content for review inside
/// JotCue; it never writes application data directly.
final class ShareViewController: UIViewController {
  private static let appGroup = "group.com.tori.pulse.share"
  private static let queueKey = "jotcue_pending_shares_v1"
  private static let maxPendingShares = 8
  private static let maxTextLength = 20_000
  private static let maxSubjectLength = 500

  private var didProcess = false

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !didProcess else { return }
    didProcess = true
    processInput()
  }

  private func processInput() {
    let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
    let subject = items
      .compactMap { $0.attributedTitle?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
      .first { !$0.isEmpty }
    let providers = items.flatMap { $0.attachments ?? [] }
    loadFirstSupportedProvider(providers, index: 0, subject: subject)
  }

  private func loadFirstSupportedProvider(
    _ providers: [NSItemProvider],
    index: Int,
    subject: String?
  ) {
    guard index < providers.count else {
      finish()
      return
    }
    let provider = providers[index]

    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
      provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) {
        [weak self] item, _ in
        if let text = self?.text(from: item), !text.isEmpty {
          self?.persist(text: text, subject: subject, mimeType: "text/plain")
        } else {
          self?.loadFirstSupportedProvider(providers, index: index + 1, subject: subject)
        }
      }
      return
    }

    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
      provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) {
        [weak self] item, _ in
        if let text = self?.text(from: item), !text.isEmpty {
          self?.persist(text: text, subject: subject, mimeType: "text/uri-list")
        } else {
          self?.loadFirstSupportedProvider(providers, index: index + 1, subject: subject)
        }
      }
      return
    }

    loadFirstSupportedProvider(providers, index: index + 1, subject: subject)
  }

  private func text(from item: NSSecureCoding?) -> String? {
    let raw: String?
    switch item {
    case let value as String:
      raw = value
    case let value as NSAttributedString:
      raw = value.string
    case let value as URL:
      raw = value.absoluteString
    default:
      raw = nil
    }
    guard let raw else { return nil }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    return String(trimmed.prefix(Self.maxTextLength))
  }

  private func persist(text: String, subject: String?, mimeType: String) {
    guard let defaults = UserDefaults(suiteName: Self.appGroup) else {
      finish()
      return
    }
    var queue = defaults.array(forKey: Self.queueKey) as? [[String: String]] ?? []
    if queue.count >= Self.maxPendingShares {
      queue.removeFirst(queue.count - Self.maxPendingShares + 1)
    }
    var payload = [
      "text": text,
      "mimeType": mimeType,
    ]
    if let subject, !subject.isEmpty {
      payload["subject"] = String(subject.prefix(Self.maxSubjectLength))
    }
    queue.append(payload)
    defaults.set(queue, forKey: Self.queueKey)
    defaults.synchronize()

    guard let url = URL(string: "jotcue://share") else {
      finish()
      return
    }
    DispatchQueue.main.async { [weak self] in
      self?.extensionContext?.open(url) { _ in
        self?.finish()
      }
    }
  }

  private func finish() {
    DispatchQueue.main.async { [weak self] in
      self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
  }
}
