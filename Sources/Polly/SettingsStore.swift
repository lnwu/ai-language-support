import AppKit
import Foundation

enum APIProvider: String, CaseIterable {
    case kimi = "Kimi (Moonshot)"
    case openAICompatible = "OpenAI 兼容"

    var displayName: String {
        switch self {
        case .kimi:
            return "provider.kimi".localized
        case .openAICompatible:
            return "provider.openai_compatible".localized
        }
    }

    var defaultApiBase: String {
        switch self {
        case .kimi:
            return "https://api.moonshot.cn/v1"
        case .openAICompatible:
            return ""
        }
    }
}

struct ProviderConfig {
    let provider: APIProvider
    var apiKey: String
    var modelName: String
    var apiBase: String

    var effectiveApiBase: String {
        switch provider {
        case .kimi:
            return APIProvider.kimi.defaultApiBase
        case .openAICompatible:
            return apiBase
        }
    }
}

struct AppSettings {
    var currentProvider: APIProvider
    var currentConfig: ProviderConfig
    var hotkey: Hotkey
}

@MainActor
final class SettingsStore {
    static let shared = SettingsStore()

    private let defaults = UserDefaults.standard
    private let keychain = KeychainStore()

    private enum Keys {
        static let currentProvider = "currentProvider"

        // Provider-specific keys
        static func apiKeyKey(for provider: APIProvider) -> String {
            "\(provider.rawValue)_apiKey"
        }
        static func modelNameKey(for provider: APIProvider) -> String {
            "\(provider.rawValue)_modelName"
        }
        static func apiBaseKey(for provider: APIProvider) -> String {
            "\(provider.rawValue)_apiBase"
        }

        // Hotkey keys
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyDisplay = "hotkeyDisplay"
    }

    func load() -> AppSettings {
        let providerRaw = defaults.string(forKey: Keys.currentProvider) ?? APIProvider.kimi.rawValue
        let currentProvider = APIProvider(rawValue: providerRaw) ?? .kimi
        let currentConfig = loadConfig(for: currentProvider)
        let hotkey = loadHotkey()
        return AppSettings(currentProvider: currentProvider, currentConfig: currentConfig, hotkey: hotkey)
    }

    func loadConfig(for provider: APIProvider) -> ProviderConfig {
        let apiKey = keychain.readPassword(account: Keys.apiKeyKey(for: provider)) ?? ""
        let modelName = defaults.string(forKey: Keys.modelNameKey(for: provider)) ?? ""
        let apiBase = defaults.string(forKey: Keys.apiBaseKey(for: provider)) ?? ""
        return ProviderConfig(provider: provider, apiKey: apiKey, modelName: modelName, apiBase: apiBase)
    }

    func save(config: ProviderConfig) {
        defaults.set(config.provider.rawValue, forKey: Keys.currentProvider)

        if !config.apiKey.isEmpty {
            keychain.save(password: config.apiKey, account: Keys.apiKeyKey(for: config.provider))
        }
        defaults.set(config.modelName, forKey: Keys.modelNameKey(for: config.provider))

        // 仅自定义 provider 存储 apiBase
        if config.provider == .openAICompatible {
            defaults.set(config.apiBase, forKey: Keys.apiBaseKey(for: config.provider))
        }
    }

    func saveHotkey(_ hotkey: Hotkey) {
        defaults.set(Int(hotkey.keyCode), forKey: Keys.hotkeyKeyCode)
        defaults.set(hotkey.modifiers.rawValue, forKey: Keys.hotkeyModifiers)
        defaults.set(hotkey.display, forKey: Keys.hotkeyDisplay)
    }

    func loadHotkey() -> Hotkey {
        if let keyCode = defaults.object(forKey: Keys.hotkeyKeyCode) as? Int,
           let modifiersValue = defaults.object(forKey: Keys.hotkeyModifiers) as? UInt,
           let display = defaults.string(forKey: Keys.hotkeyDisplay) {
            let modifiers = NSEvent.ModifierFlags(rawValue: modifiersValue)
            return Hotkey(keyCode: UInt32(keyCode), modifiers: modifiers, display: display)
        }
        return Hotkey.default()
    }
}
