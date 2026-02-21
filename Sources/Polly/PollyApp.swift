import SwiftUI

@main
struct PollyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var appState = AppState.shared
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        MenuBarExtra {
            Button("设置…") {
                openSettingsWindow()
            }
            .keyboardShortcut(",")
            Divider()
            Button("退出") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image("StatusBarIcon")
        }
        .onChange(of: appState.needsOpenSettings) { _, newValue in
            if newValue {
                appState.needsOpenSettings = false
                openSettingsWindow()
            }
        }

        Settings {
            SettingsView()
        }
    }

    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            openSettings()
        }
    }
}
