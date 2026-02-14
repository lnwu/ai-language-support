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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Language Optimizer Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("API Base", text: $apiBase)
                SecureField("API Key", text: $apiKey)
                Picker("Model", selection: $modelName) {
                    ForEach(models, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .disabled(models.isEmpty)
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
        .onAppear {
            loadSettingsIfNeeded()
        }
        .onChange(of: apiBase) { _ in
            scheduleModelsFetchIfNeeded()
        }
        .onChange(of: apiKey) { _ in
            scheduleModelsFetchIfNeeded()
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
}
