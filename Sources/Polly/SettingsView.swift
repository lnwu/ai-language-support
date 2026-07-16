import SwiftUI

@MainActor
struct SettingsView: View {
  @State private var apiProvider: APIProvider = .deepseek
  @State private var apiBase: String = ""
  @State private var modelName: String = ""
  @State private var apiKey: String = ""
  @State private var loaded = false
  @State private var isLoadingModels = false
  @State private var models: [String] = []
  @State private var errorText: String = ""
  @State private var lastFetchedKey: String = ""
  @AppStorage("selectedSettingsTab") private var selectedTab: SettingsTab = .permissions
  @State private var isTrusted = false
  @State private var permissionTimer: Timer?
  @State private var testText: String = "how you are"
  @State private var hotkey: Hotkey = Hotkey.default()
  @State private var isRecordingHotkey = false
  @State private var hotkeyError: String = ""
  @State private var hotkeyMonitor: Any?

  private let permissionManager = PermissionManager()

  var body: some View {
    TabView(selection: $selectedTab) {
      permissionsTab
        .tabItem {
          Label("tab.permissions".localized, systemImage: "hand.raised.fill")
        }
        .tag(SettingsTab.permissions)

      generalTab
        .tabItem {
          Label("tab.general".localized, systemImage: "gearshape")
        }
        .tag(SettingsTab.general)

      testingTab
        .tabItem {
          Label("tab.testing".localized, systemImage: "play.circle")
        }
        .tag(SettingsTab.testing)

      logsTab
        .tabItem {
          Label("tab.logs".localized, systemImage: "doc.text")
        }
        .tag(SettingsTab.logs)

      hotkeyTab
        .tabItem {
          Label("tab.hotkey".localized, systemImage: "keyboard")
        }
        .tag(SettingsTab.hotkey)
    }
    .frame(width: 640, height: 520)
    .onAppear {
      loadSettingsIfNeeded()
      refreshPermissionStatus()
      startPermissionPolling()
    }
    .onDisappear {
      stopRecordingHotkey()
      stopPermissionPolling()
    }
    .onChange(of: selectedTab) { _, newValue in
      if newValue == .permissions {
        refreshPermissionStatus()
      }
    }
    .onChange(of: apiBase) { _, _ in
      scheduleModelsFetchIfNeeded()
      persistCurrentConfig()
    }
    .onChange(of: apiKey) { _, _ in
      scheduleModelsFetchIfNeeded()
      persistCurrentConfig()
    }
    .onChange(of: modelName) { _, _ in
      persistCurrentConfig()
    }
  }

  private var generalTab: some View {
    VStack(alignment: .leading, spacing: 16) {
      Form {
        Section("section.api".localized) {
          Picker("field.provider".localized, selection: $apiProvider) {
            ForEach(APIProvider.allCases, id: \.self) { provider in
              Text(provider.displayName).tag(provider)
            }
          }

          SecureField("field.api_key".localized, text: $apiKey)
          Text("info.keychain".localized)
            .font(.caption)
            .foregroundColor(.secondary)
          Picker("field.model".localized, selection: $modelName) {
            ForEach(models, id: \.self) { model in
              Text(model).tag(model)
            }
          }
          .disabled(models.isEmpty)
        }
        if isLoadingModels {
          Text("status.loading_models".localized)
        }
        if !errorText.isEmpty {
          Text(errorText)
            .foregroundColor(.red)
        }
      }
    }
    .padding(20)
  }

  private var testingTab: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("testing.instruction".localized(hotkey.display))
        .font(.subheadline)
        .foregroundColor(.secondary)

      TextEditor(text: $testText)
        .font(.body)
        .frame(minHeight: 200)
    }
    .padding(20)
  }

  private var logsTab: some View {
    LogsTabView()
  }

  private var hotkeyTab: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("hotkey.current".localized)
        .font(.headline)

      Text(hotkey.display)
        .font(.system(size: 28, weight: .semibold))

      if !hotkeyError.isEmpty {
        Text(hotkeyError)
          .foregroundColor(.red)
      }

      HStack(spacing: 12) {
        Button(isRecordingHotkey ? "hotkey.button.recording".localized : "hotkey.button.record".localized) {
          if isRecordingHotkey {
            stopRecordingHotkey()
          } else {
            startRecordingHotkey()
          }
        }
        .buttonStyle(.borderedProminent)

        Button("hotkey.button.reset".localized) {
          applyHotkey(Hotkey.default())
        }
      }

      Text("hotkey.instruction".localized)
        .font(.subheadline)
        .foregroundColor(.secondary)

      Spacer()
    }
    .padding(20)
    .frame(minHeight: 300)
  }

  private var permissionsTab: some View {
    VStack(spacing: 20) {
      Spacer()

      Image(systemName: isTrusted ? "checkmark.shield.fill" : "lock.shield")
        .font(.system(size: 48))
        .foregroundColor(isTrusted ? .green : .secondary)

      Text(isTrusted ? "permission.granted".localized : "permission.required".localized)
        .font(.headline)

      Text(isTrusted
        ? "permission.description.granted".localized
        : "permission.description.required".localized)
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 320)

      if !isTrusted {
        Button(action: {
          permissionManager.requestAccess()
        }) {
          Text("permission.button.request".localized)
            .frame(maxWidth: 200)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .padding(.top, 16)
      }

      Spacer()
    }
    .frame(maxWidth: .infinity)
    .padding(20)
  }

  private func loadSettingsIfNeeded() {
    guard !loaded else { return }
    let settings = SettingsStore.shared.load()
    apiProvider = settings.currentProvider
    apiKey = settings.currentConfig.apiKey
    modelName = settings.currentConfig.modelName
    apiBase = settings.currentConfig.apiBase
    hotkey = settings.hotkey
    loaded = true
    scheduleModelsFetchIfNeeded()
  }

  private func persistCurrentConfig() {
    guard loaded else { return }
    let config = ProviderConfig(provider: apiProvider, apiKey: apiKey, modelName: modelName, apiBase: apiBase)
    SettingsStore.shared.save(config: config)
  }

  private func scheduleModelsFetchIfNeeded() {
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
    let fingerprint = "\(effectiveBase)|\(key)"
    guard fingerprint != lastFetchedKey else { return }
    lastFetchedKey = fingerprint
    Task { await fetchModels(apiBase: effectiveBase, apiKey: key) }
  }

  private func fetchModels(apiBase: String, apiKey: String) async {
    isLoadingModels = true
    errorText = ""
    models = []

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

  private func refreshPermissionStatus() {
    isTrusted = permissionManager.isTrusted()
    if isTrusted {
      stopPermissionPolling()
    }
  }

  private func startRecordingHotkey() {
    hotkeyError = ""
    isRecordingHotkey = true
    if let monitor = hotkeyMonitor {
      NSEvent.removeMonitor(monitor)
      hotkeyMonitor = nil
    }
    hotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      guard isRecordingHotkey else { return event }
      if Hotkey.isModifierKeyCode(event.keyCode) {
        return nil
      }
      let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      if modifiers.isDisjoint(with: [.command, .control, .option, .shift]) {
        hotkeyError = "hotkey.error.modifier_required".localized
        return nil
      }
      let candidate = Hotkey.build(keyCode: event.keyCode, modifiers: modifiers, displayKey: event.charactersIgnoringModifiers)
      applyHotkey(candidate)
      isRecordingHotkey = false
      return nil
    }
  }

  private func stopRecordingHotkey() {
    isRecordingHotkey = false
    if let monitor = hotkeyMonitor {
      NSEvent.removeMonitor(monitor)
      hotkeyMonitor = nil
    }
  }

  private func applyHotkey(_ newHotkey: Hotkey) {
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

  private func startPermissionPolling() {
    stopPermissionPolling()
    permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
      Task { @MainActor in
        refreshPermissionStatus()
      }
    }
  }

  private func stopPermissionPolling() {
    permissionTimer?.invalidate()
    permissionTimer = nil
  }
}
