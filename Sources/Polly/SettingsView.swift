import SwiftUI
import Foundation

@MainActor
struct SettingsView: View {
    @State private var apiProvider: APIProvider = .openAICompatible
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
    @State private var showSavedToast = false

    private let permissionManager = PermissionManager()

    var body: some View {
        TabView(selection: $selectedTab) {
            permissionsTab
                .tabItem {
                    Label("权限", systemImage: "hand.raised.fill")
                }
                .tag(SettingsTab.permissions)

            generalTab
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            testingTab
                .tabItem {
                    Label("测试", systemImage: "play.circle")
                }
                .tag(SettingsTab.testing)

            logsTab
                .tabItem {
                    Label("日志", systemImage: "doc.text")
                }
                .tag(SettingsTab.logs)

            hotkeyTab
                .tabItem {
                    Label("快捷键", systemImage: "keyboard")
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
        }
        .onDisappear {
            stopPermissionPolling()
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .permissions {
                refreshPermissionStatus()
            }
        }
        .onChange(of: apiBase) { _, _ in
            scheduleModelsFetchIfNeeded()
        }
        .onChange(of: apiKey) { _, _ in
            scheduleModelsFetchIfNeeded()
        }
    }

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Section("API") {
                    Picker("Provider", selection: $apiProvider) {
                        ForEach(APIProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: apiProvider) { _, newProvider in
                        // 加载新 provider 的配置（不保存当前）
                        let config = SettingsStore.shared.loadConfig(for: newProvider)
                        apiKey = config.apiKey
                        modelName = config.modelName
                        apiBase = config.apiBase
                        models = []
                        lastFetchedKey = ""
                        scheduleModelsFetchIfNeeded()
                    }

                    if apiProvider == .openAICompatible {
                        TextField("API Base", text: $apiBase)
                    }

                    SecureField("API Key", text: $apiKey)
                    Text("API Key 将使用 macOS Keychain 安全存储。首次保存时系统可能弹出授权弹窗。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Model", selection: $modelName) {
                        ForEach(models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .disabled(models.isEmpty)
                }
                if isLoadingModels {
                    Text("正在加载模型列表…")
                }
                if let hint = formHint {
                    Text(hint)
                        .foregroundColor(.red)
                }
                if !errorText.isEmpty {
                    Text(errorText)
                        .foregroundColor(.red)
                }
            }

            HStack {
                Spacer()
                if showSavedToast {
                    Text("已保存")
                        .foregroundColor(.green)
                        .transition(.opacity)
                }
                Button("Save") {
                    saveSettings()
                }
                .disabled(!isFormValid)
            }
        }
        .padding(20)
    }

    private var testingTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选中下方文字或输入新内容，按 \(hotkey.display) 优化")
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
            Text("当前快捷键")
                .font(.headline)

            Text(hotkey.display)
                .font(.system(size: 28, weight: .semibold))

            if !hotkeyError.isEmpty {
                Text(hotkeyError)
                    .foregroundColor(.red)
            }

            HStack(spacing: 12) {
                Button(isRecordingHotkey ? "按下新的快捷键…" : "录制快捷键") {
                    if isRecordingHotkey {
                        stopRecordingHotkey()
                    } else {
                        startRecordingHotkey()
                    }
                }
                .buttonStyle(.borderedProminent)

                Button("恢复默认") {
                    applyHotkey(Hotkey.default())
                }
            }

            Text("录制时按下任意组合键，建议包含 ⌘/⌃/⌥ 中至少一个。")
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

            Text(isTrusted ? "辅助功能权限已开启" : "需要辅助功能权限")
                .font(.headline)

            Text(isTrusted
                 ? "可以使用快捷键读取并优化任意应用选中文本。"
                 : "开启后即可通过快捷键读取并优化任意应用选中文本。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if !isTrusted {
                Button(action: {
                    permissionManager.requestAccess()
                }) {
                    Text("请求权限")
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

    private func saveSettings() {
        let config = ProviderConfig(provider: apiProvider, apiKey: apiKey, modelName: modelName, apiBase: apiBase)
        SettingsStore.shared.save(config: config)
        withAnimation {
            showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSavedToast = false
            }
        }
    }

    private var isFormValid: Bool {
        let apiBaseValid = apiProvider == .kimi || !apiBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return apiBaseValid &&
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var formHint: String? {
        if isFormValid {
            return nil
        }
        let needsApiBase = apiProvider == .openAICompatible && apiBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if needsApiBase || apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if needsApiBase {
                return "请填写 API Base 和 API Key"
            } else {
                return "请填写 API Key"
            }
        }
        if modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请先获取模型列表"
        }
        return nil
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
        let fingerprint = "\(apiProvider.rawValue)|\(effectiveBase)|\(key)"
        guard fingerprint != lastFetchedKey else { return }
        lastFetchedKey = fingerprint
        fetchModels(apiBase: effectiveBase, apiKey: key)
    }

    private func fetchModels(apiBase: String, apiKey: String) {
        isLoadingModels = true
        errorText = ""
        models = []

        guard let url = URL(string: "\(apiBase)/models") else {
            isLoadingModels = false
            errorText = "API 地址无效"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                isLoadingModels = false
                if let error = error {
                    errorText = "获取模型列表失败: \(error.localizedDescription)"
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    errorText = "获取模型列表失败: 无效的响应"
                    return
                }
                guard (200...299).contains(http.statusCode) else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(empty)"
                    errorText = "获取模型列表失败 (HTTP \(http.statusCode)): \(body)"
                    return
                }
                guard let data = data else {
                    errorText = "获取模型列表失败: 无数据"
                    return
                }

                guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
                      let dict = object as? [String: Any],
                      let items = dict["data"] as? [[String: Any]] else {
                    errorText = "模型列表解析失败"
                    return
                }

                let names = items.compactMap { $0["id"] as? String }
                models = names
                if let first = names.first {
                    if modelName.isEmpty || !names.contains(modelName) {
                        modelName = first
                    }
                } else {
                    errorText = "模型列表为空"
                }
            }
        }
        task.resume()
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
                hotkeyError = "请至少包含一个修饰键"
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
            hotkeyError = "快捷键已被占用"
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

@MainActor
struct LogsTabView: View {
    @State private var entries: [APILogEntry] = []
    @State private var appEntries: [AppLogEntry] = []
    @State private var expandedIds: Set<UUID> = []
    @State private var selectedLogType: LogType = .app
    @State private var appOnlyErrors = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Picker("日志", selection: $selectedLogType) {
                    Text("应用日志").tag(LogType.app)
                    Text("API 日志").tag(LogType.api)
                }
                .pickerStyle(.segmented)

                Spacer()
            }

            HStack {
                Text(selectedLogType == .app ? "应用日志" : "API 调用日志")
                    .font(.headline)
                Spacer()
                if selectedLogType == .app {
                    Toggle("仅错误", isOn: $appOnlyErrors)
                        .toggleStyle(.switch)
                    Button("清空日志") {
                        AppLogStore.shared.clearAll()
                        appEntries = AppLogStore.shared.entries
                    }
                    .disabled(appEntries.isEmpty)
                } else {
                    Button("清空日志") {
                        APILogStore.shared.clearAll()
                        entries = APILogStore.shared.entries
                    }
                    .disabled(entries.isEmpty)
                }
            }

            logList
        }
        .padding(20)
        .onAppear {
            entries = APILogStore.shared.entries
            appEntries = AppLogStore.shared.entries
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("APILogUpdated"))) { _ in
            entries = APILogStore.shared.entries
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppLogUpdated"))) { _ in
            appEntries = AppLogStore.shared.entries
        }
    }
    
    private func toggleExpanded(_ id: UUID) {
        if expandedIds.contains(id) {
            expandedIds.remove(id)
        } else {
            expandedIds.insert(id)
        }
    }

    private var logList: some View {
        Group {
            if selectedLogType == .app {
                let filtered = appOnlyErrors ? appEntries.filter { $0.level == .error } : appEntries
                if filtered.isEmpty {
                    Spacer()
                    Text("暂无日志")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(filtered) { entry in
                        AppLogEntryRow(
                            entry: entry,
                            isExpanded: expandedIds.contains(entry.id),
                            dateFormatter: dateFormatter
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleExpanded(entry.id)
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                if entries.isEmpty {
                    Spacer()
                    Text("暂无日志")
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(entries) { entry in
                        LogEntryRow(
                            entry: entry,
                            isExpanded: expandedIds.contains(entry.id),
                            dateFormatter: dateFormatter
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleExpanded(entry.id)
                        }
                    }
                    .listStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}

enum LogType: String, Hashable {
    case app
    case api
}

struct AppLogEntryRow: View {
    let entry: AppLogEntry
    let isExpanded: Bool
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(dateFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: levelIcon)
                    .foregroundColor(levelColor)
                    .font(.caption)

                Text("[\(entry.category)] \(entry.message)")
                    .font(.body)
                    .lineLimit(1)

                Spacer()
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    LogSection(title: "级别", content: entry.level.rawValue)
                    if let detail = entry.detail {
                        LogSection(title: "详情", content: detail)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }

    private var levelIcon: String {
        switch entry.level {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    private var levelColor: Color {
        switch entry.level {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct LogEntryRow: View {
    let entry: APILogEntry
    let isExpanded: Bool
    let dateFormatter: DateFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(dateFormatter.string(from: entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                Image(systemName: entry.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(entry.isSuccess ? .green : .red)
                    .font(.caption)
                
                let seconds = Double(entry.responseTimeMs) / 1000.0
                Text(String(format: "%.1fs", seconds))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(previewText)
                    .font(.body)
                    .lineLimit(1)
                    
                Spacer()
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    LogSection(title: "原始文本", content: entry.requestContent)
                    LogSection(title: "请求体", content: entry.requestBody, isJSON: true)
                    
                    if let response = entry.responseContent {
                        LogSection(title: "响应", content: response)
                    }
                    
                    if let error = entry.errorMessage {
                        LogSection(title: "错误", content: error, isError: true)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var previewText: String {
        let text = entry.requestContent
        if text.count > 30 {
            return String(text.prefix(30)) + "..."
        }
        return text
    }
}

struct LogSection: View {
    let title: String
    let content: String
    var isJSON: Bool = false
    var isError: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundColor(isError ? .red : .secondary)
            
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(isError ? .red : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(4)
        }
    }
}
