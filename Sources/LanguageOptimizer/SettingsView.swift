import SwiftUI

@MainActor
struct SettingsView: View {
    @State private var apiBase: String = "https://api.openai.com/v1"
    @State private var modelName: String = "gpt-4.1-mini"
    @State private var goal: String = "修复语法和拼写错误，尽量更简洁"
    @State private var apiKey: String = ""
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Language Optimizer Settings")
                .font(.title2)
                .fontWeight(.semibold)

            Form {
                TextField("API Base", text: $apiBase)
                SecureField("API Key", text: $apiKey)
                TextField("Model", text: $modelName)
                TextField("Default Goal", text: $goal)
            }

            HStack {
                Spacer()
                Button("Save") {
                    saveSettings()
                }
            }
        }
        .padding(20)
        .onAppear {
            loadSettingsIfNeeded()
        }
    }

    private func loadSettingsIfNeeded() {
        guard !loaded else { return }
        let settings = SettingsStore.shared.load()
        apiBase = settings.apiBase
        modelName = settings.modelName
        goal = settings.goal
        apiKey = SettingsStore.shared.apiKey() ?? ""
        loaded = true
    }

    private func saveSettings() {
        let settings = AppSettings(apiBase: apiBase, modelName: modelName, goal: goal)
        SettingsStore.shared.save(settings: settings, apiKey: apiKey)
    }
}
