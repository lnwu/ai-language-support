import AppKit
import Foundation

enum APIProvider: String, CaseIterable {
  case deepseek = "DeepSeek"

  var displayName: String {
    switch self {
    case .deepseek:
      return "provider.deepseek".localized
    }
  }

  var defaultApiBase: String {
    switch self {
    case .deepseek:
      return "https://api.deepseek.com"
    }
  }
}

struct ProviderConfig {
  let provider: APIProvider
  var apiKey: String
  var modelName: String
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

    // Hotkey keys
    static let hotkeyKeyCode = "hotkeyKeyCode"
    static let hotkeyModifiers = "hotkeyModifiers"
    static let hotkeyDisplay = "hotkeyDisplay"
  }

  func load() -> AppSettings {
    let providerRaw = defaults.string(forKey: Keys.currentProvider) ?? APIProvider.deepseek.rawValue
    let currentProvider = APIProvider(rawValue: providerRaw) ?? .deepseek
    let currentConfig = loadConfig(for: currentProvider)
    let hotkey = loadHotkey()
    return AppSettings(currentProvider: currentProvider, currentConfig: currentConfig, hotkey: hotkey)
  }

  func loadConfig(for provider: APIProvider) -> ProviderConfig {
    let apiKey = keychain.readPassword(account: Keys.apiKeyKey(for: provider)) ?? ""
    let modelName = defaults.string(forKey: Keys.modelNameKey(for: provider)) ?? ""
    return ProviderConfig(provider: provider, apiKey: apiKey, modelName: modelName)
  }

  func save(config: ProviderConfig) {
    defaults.set(config.provider.rawValue, forKey: Keys.currentProvider)

    let apiKeyAccount = Keys.apiKeyKey(for: config.provider)
    if config.apiKey.isEmpty {
      keychain.deletePassword(account: apiKeyAccount)
    } else {
      keychain.save(password: config.apiKey, account: apiKeyAccount)
    }
    defaults.set(config.modelName, forKey: Keys.modelNameKey(for: config.provider))
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
