import Foundation

struct AppSettings {
    var apiBase: String
    var modelName: String
    var goal: String
}

@MainActor
final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private let keychain = KeychainStore()

    private enum Keys {
        static let apiBase = "apiBase"
        static let modelName = "modelName"
        static let goal = "goal"
        static let apiKeyAccount = "openaiApiKey"
    }

    func load() -> AppSettings {
        let apiBase = defaults.string(forKey: Keys.apiBase) ?? "https://api.openai.com/v1"
        let modelName = defaults.string(forKey: Keys.modelName) ?? "gpt-4.1-mini"
        let goal = defaults.string(forKey: Keys.goal) ?? "修复语法和拼写错误，尽量更简洁"
        return AppSettings(apiBase: apiBase, modelName: modelName, goal: goal)
    }

    func save(settings: AppSettings, apiKey: String?) {
        defaults.set(settings.apiBase, forKey: Keys.apiBase)
        defaults.set(settings.modelName, forKey: Keys.modelName)
        defaults.set(settings.goal, forKey: Keys.goal)

        if let apiKey, !apiKey.isEmpty {
            keychain.save(password: apiKey, account: Keys.apiKeyAccount)
        }
    }

    func apiKey() -> String? {
        keychain.readPassword(account: Keys.apiKeyAccount)
    }
}
