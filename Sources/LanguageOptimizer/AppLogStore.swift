import Foundation

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

    private let defaults = UserDefaults.standard
    private let storageKey = "appLogs"
    private let maxEntries = 200

    private(set) var entries: [AppLogEntry] = []

    init() {
        loadEntries()
    }

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
        saveEntries()
        NotificationCenter.default.post(name: NSNotification.Name("AppLogUpdated"), object: nil)
    }

    nonisolated static func log(level: AppLogLevel, category: String, message: String, detail: String? = nil) {
        Task { @MainActor in
            shared.add(level: level, category: category, message: message, detail: detail)
        }
    }

    nonisolated static func clear() {
        Task { @MainActor in
            shared.clearAll()
        }
    }

    func clearAll() {
        entries.removeAll()
        defaults.removeObject(forKey: storageKey)
        NotificationCenter.default.post(name: NSNotification.Name("AppLogUpdated"), object: nil)
    }

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func loadEntries() {
        guard let data = defaults.data(forKey: storageKey),
              let loaded = try? JSONDecoder().decode([AppLogEntry].self, from: data) else {
            return
        }
        entries = loaded
    }
}
