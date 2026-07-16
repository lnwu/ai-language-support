import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
  @Published var apiProvider: APIProvider = .deepseek
  @Published var apiBase: String = ""
  @Published var modelName: String = ""
  @Published var apiKey: String = ""
  @Published var loaded = false
  @Published var isLoadingModels = false
  @Published var models: [String] = []
  @Published var errorText: String = ""
  @Published var isTrusted = false
  @Published var testText: String = "how you are"
  @Published var hotkey: Hotkey = Hotkey.default()
  @Published var isRecordingHotkey = false
  @Published var hotkeyError: String = ""
  var hotkeyMonitor: Any?
  var permissionTimer: Timer?

  let permissionManager = PermissionManager()

  func loadSettingsIfNeeded() {
    guard !loaded else { return }
    let settings = SettingsStore.shared.load()
    apiProvider = settings.currentProvider
    apiKey = settings.currentConfig.apiKey
    modelName = settings.currentConfig.modelName
    apiBase = settings.currentConfig.apiBase
    hotkey = settings.hotkey
    loaded = true
    
    if !apiKey.isEmpty && !modelName.isEmpty {
      let config = ProviderConfig(provider: apiProvider, apiKey: apiKey, modelName: modelName, apiBase: apiBase)
      Task { await fetchModels(apiBase: config.effectiveApiBase, apiKey: apiKey) }
    }
  }

  func persistCurrentConfig() {
    guard loaded else { return }
    let config = ProviderConfig(provider: apiProvider, apiKey: apiKey, modelName: modelName, apiBase: apiBase)
    SettingsStore.shared.save(config: config)
  }

  func refreshModels() {
    guard loaded else { return }
    let config = ProviderConfig(provider: apiProvider, apiKey: apiKey, modelName: modelName, apiBase: apiBase)
    let effectiveBase = config.effectiveApiBase
    let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !effectiveBase.isEmpty, !key.isEmpty else {
      models = []
      modelName = ""
      errorText = ""
      return
    }
    Task { await fetchModels(apiBase: effectiveBase, apiKey: key) }
  }

  func fetchModels(apiBase: String, apiKey: String) async {
    isLoadingModels = true
    errorText = ""

    guard let url = URL(string: "\(apiBase)/models") else {
      isLoadingModels = false
      errorText = "error.api_invalid".localized
      return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      isLoadingModels = false
      errorText = "error.fetch_models_failed".localized(error.localizedDescription)
      return
    }

    isLoadingModels = false

    guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
      let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
      let body = String(data: data, encoding: .utf8) ?? "(empty)"
      errorText = "error.fetch_models_http".localized(statusCode, body)
      return
    }

    guard let modelsResponse = try? JSONDecoder().decode(ModelsResponse.self, from: data) else {
      errorText = "error.parse_models_failed".localized
      return
    }

    let names = modelsResponse.data.map(\.id)
    models = names
    if let first = names.first {
      if modelName.isEmpty || !names.contains(modelName) {
        modelName = first
      }
    } else {
      errorText = "error.models_empty".localized
    }
  }

  func refreshPermissionStatus() {
    isTrusted = permissionManager.isTrusted()
    if isTrusted {
      stopPermissionPolling()
    }
  }

  func startRecordingHotkey() {
    hotkeyError = ""
    isRecordingHotkey = true
    if let monitor = hotkeyMonitor {
      NSEvent.removeMonitor(monitor)
      hotkeyMonitor = nil
    }
    hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, self.isRecordingHotkey else { return event }
      if Hotkey.isModifierKeyCode(event.keyCode) {
        return nil
      }
      let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      if modifiers.isDisjoint(with: [.command, .control, .option, .shift]) {
        self.hotkeyError = "hotkey.error.modifier_required".localized
        return nil
      }
      let candidate = Hotkey.build(keyCode: event.keyCode, modifiers: modifiers, displayKey: event.charactersIgnoringModifiers)
      self.applyHotkey(candidate)
      self.isRecordingHotkey = false
      return nil
    }
  }

  func stopRecordingHotkey() {
    isRecordingHotkey = false
    if let monitor = hotkeyMonitor {
      NSEvent.removeMonitor(monitor)
      hotkeyMonitor = nil
    }
  }

  func applyHotkey(_ newHotkey: Hotkey) {
    let manager = AppState.shared.hotkeyManager
    let previous = hotkey
    let didRegister = manager?.register(newHotkey) ?? true
    if didRegister {
      hotkey = newHotkey
      SettingsStore.shared.saveHotkey(newHotkey)
      hotkeyError = ""
    } else {
      _ = manager?.register(previous)
      hotkeyError = "hotkey.error.occupied".localized
    }
  }

  func startPermissionPolling() {
    stopPermissionPolling()
    permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
      Task { @MainActor in
        self?.refreshPermissionStatus()
      }
    }
  }

  func stopPermissionPolling() {
    permissionTimer?.invalidate()
    permissionTimer = nil
  }
}
