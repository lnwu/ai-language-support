import Foundation

struct APILogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let requestContent: String
    let requestBody: String
    let responseContent: String?
    let isSuccess: Bool
    let errorMessage: String?
    let responseTimeMs: Int
}

@MainActor
final class APILogStore {
    static let shared = APILogStore()
    
    private let maxEntries = 50
    
    private(set) var entries: [APILogEntry] = []
    
    func add(requestContent: String, requestBody: String, responseContent: String?, isSuccess: Bool, errorMessage: String? = nil, responseTimeMs: Int = 0) {
        let entry = APILogEntry(
            id: UUID(),
            timestamp: Date(),
            requestContent: requestContent,
            requestBody: requestBody,
            responseContent: responseContent,
            isSuccess: isSuccess,
            errorMessage: errorMessage,
            responseTimeMs: responseTimeMs
        )
        
        entries.insert(entry, at: 0)
        
        if entries.count > maxEntries {
            entries.removeLast()
        }
        
        NotificationCenter.default.post(name: NSNotification.Name("APILogUpdated"), object: nil)
    }
    
    func clearAll() {
        entries.removeAll()
        NotificationCenter.default.post(name: NSNotification.Name("APILogUpdated"), object: nil)
    }
}
