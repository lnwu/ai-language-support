import SwiftUI
import Foundation

@MainActor
struct SettingsView: View {
    @State private var apiBase: String = "https://api.openai.com/v1"
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
    @State private var testText: String = ""

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
        }
        .onAppear {
            loadSettingsIfNeeded()
            refreshPermissionStatus()
            startPermissionPolling()
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
                    TextField("API Base", text: $apiBase)
                    SecureField("API Key", text: $apiKey)
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
            Text("在下方输入文本，选中后按 ⌘E 测试优化功能")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $testText)
                .font(.body)
                .frame(minHeight: 200)
        }
        .padding(20)
    }

    private var permissionsTab: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: isTrusted ? "checkmark.shield.fill" : "lock.shield")
                .font(.system(size: 48))
                .foregroundColor(isTrusted ? .green : .secondary)

            Text(isTrusted ? "辅助功能权限已开启" : "需要辅助功能权限")
                .font(.headline)

            Text(isTrusted
                 ? "可以使用快捷键读取并优化 Slack 选中文本。"
                 : "开启后即可通过快捷键读取并优化 Slack 选中文本。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if !isTrusted {
                VStack(alignment: .leading, spacing: 8) {
                    stepRow(number: 1, text: "点击下方按钮")
                    stepRow(number: 2, text: "在系统弹窗中确认授权")
                    stepRow(number: 3, text: "返回此页面查看状态")
                }
                .padding(.horizontal, 40)

                Button(action: {
                    permissionManager.requestAccess()
                }) {
                    Text("请求权限")
                        .frame(maxWidth: 200)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func loadSettingsIfNeeded() {
        guard !loaded else { return }
        let settings = SettingsStore.shared.load()
        apiBase = settings.apiBase
        modelName = settings.modelName
        apiKey = SettingsStore.shared.apiKey() ?? ""
        loaded = true
        scheduleModelsFetchIfNeeded()
    }

    private func saveSettings() {
        let settings = AppSettings(apiBase: apiBase, modelName: modelName)
        SettingsStore.shared.save(settings: settings, apiKey: apiKey)
    }

    private var isFormValid: Bool {
        !apiBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var formHint: String? {
        if isFormValid {
            return nil
        }
        if apiBase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请填写 API Base 和 API Key"
        }
        if modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请先获取模型列表"
        }
        return nil
    }

    private func scheduleModelsFetchIfNeeded() {
        guard loaded else { return }
        let base = apiBase.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, !key.isEmpty else {
            models = []
            modelName = ""
            errorText = ""
            return
        }
        let fingerprint = "\(base)|\(key)"
        guard fingerprint != lastFetchedKey else { return }
        lastFetchedKey = fingerprint
        fetchModels(apiBase: base, apiKey: key)
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
                if error != nil {
                    errorText = "获取模型列表失败"
                    return
                }
                guard let http = response as? HTTPURLResponse,
                      (200...299).contains(http.statusCode),
                      let data else {
                    errorText = "获取模型列表失败"
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
