import Foundation

struct APILogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let requestContent: String
    let requestBody: String
    let responseContent: String?
    let isSuccess: Bool
    let errorMessage: String?
}

@MainActor
final class APILogStore {
    static let shared = APILogStore()
    
    private let defaults = UserDefaults.standard
    private let storageKey = "apiLogs"
    private let maxEntries = 50
    
    private(set) var entries: [APILogEntry] = []
    
    init() {
        loadEntries()
    }
    
    func add(requestContent: String, requestBody: String, responseContent: String?, isSuccess: Bool, errorMessage: String? = nil) {
        let entry = APILogEntry(
            id: UUID(),
            timestamp: Date(),
            requestContent: requestContent,
            requestBody: requestBody,
            responseContent: responseContent,
            isSuccess: isSuccess,
            errorMessage: errorMessage
        )
        
        entries.insert(entry, at: 0)
        
        if entries.count > maxEntries {
            entries.removeLast()
        }
        
        saveEntries()
    }
    
    func clearAll() {
        entries.removeAll()
        defaults.removeObject(forKey: storageKey)
    }
    
    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: storageKey)
        }
    }
    
    private func loadEntries() {
        guard let data = defaults.data(forKey: storageKey),
              let loaded = try? JSONDecoder().decode([APILogEntry].self, from: data) else {
            return
        }
        entries = loaded
    }
}
