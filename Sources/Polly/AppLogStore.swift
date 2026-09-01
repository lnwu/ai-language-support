import Foundation

extension NSNotification.Name {
  static let appLogUpdated = NSNotification.Name("AppLogUpdated")
  static let apiLogUpdated = NSNotification.Name("APILogUpdated")
}

enum AppLogLevel: String, Codable {
  case info
  case warning
  case error
}

struct AppLogEntry: Identifiable, Codable {
  let id: UUID
  let timestamp: Date
  let level: AppLogLevel
  let category: String
  let message: String
  let detail: String?
}

@MainActor
final class AppLogStore {
  static let shared = AppLogStore()

  private let maxEntries = 200

  private(set) var entries: [AppLogEntry] = []

  func add(level: AppLogLevel, category: String, message: String, detail: String? = nil) {
    let entry = AppLogEntry(
      id: UUID(),
      timestamp: Date(),
      level: level,
      category: category,
      message: message,
      detail: detail
    )

    entries.insert(entry, at: 0)
    if entries.count > maxEntries {
      entries.removeLast()
    }
    NotificationCenter.default.post(name: .appLogUpdated, object: nil)
  }

  func clearAll() {
    entries.removeAll()
    NotificationCenter.default.post(name: .appLogUpdated, object: nil)
  }
}
