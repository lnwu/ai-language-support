import AppKit
import Foundation

struct AppSettings {
    var apiBase: String
    var modelName: String
    var hotkey: Hotkey
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
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let hotkeyDisplay = "hotkeyDisplay"
    }

    func load() -> AppSettings {
        let apiBase = defaults.string(forKey: Keys.apiBase) ?? ""
        let modelName = defaults.string(forKey: Keys.modelName) ?? ""
        let hotkey = loadHotkey()
        return AppSettings(apiBase: apiBase, modelName: modelName, hotkey: hotkey)
    }

    func save(settings: AppSettings, apiKey: String?) {
        defaults.set(settings.apiBase, forKey: Keys.apiBase)
        defaults.set(settings.modelName, forKey: Keys.modelName)
        saveHotkey(settings.hotkey)

        if let apiKey, !apiKey.isEmpty {
            keychain.save(password: apiKey, account: Keys.apiKeyAccount)
        }
    }

    func apiKey() -> String? {
        keychain.readPassword(account: Keys.apiKeyAccount)
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

    func saveHotkey(_ hotkey: Hotkey) {
        defaults.set(Int(hotkey.keyCode), forKey: Keys.hotkeyKeyCode)
        defaults.set(hotkey.modifiers.rawValue, forKey: Keys.hotkeyModifiers)
        defaults.set(hotkey.display, forKey: Keys.hotkeyDisplay)
    }
}
