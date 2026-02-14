import Foundation

struct AppSettings {
    var apiBase: String
    var modelName: String
}

@MainActor
final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private let keychain = KeychainStore()

    private enum Keys {
        static let apiBase = "apiBase"
        static let modelName = "modelName"
        static let apiKeyAccount = "openaiApiKey"
    }

    func load() -> AppSettings {
        let apiBase = defaults.string(forKey: Keys.apiBase) ?? "https://api.openai.com/v1"
        let modelName = defaults.string(forKey: Keys.modelName) ?? ""
        return AppSettings(apiBase: apiBase, modelName: modelName)
    }

    func save(settings: AppSettings, apiKey: String?) {
        defaults.set(settings.apiBase, forKey: Keys.apiBase)
        defaults.set(settings.modelName, forKey: Keys.modelName)

        if let apiKey, !apiKey.isEmpty {
            keychain.save(password: apiKey, account: Keys.apiKeyAccount)
        }
    }

    func apiKey() -> String? {
        keychain.readPassword(account: Keys.apiKeyAccount)
    }
}
