import SwiftUI

@main
struct PollyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        MenuBarExtra {
            Button("menu.settings".localized) {
                openSettingsWindow()
            }
            .keyboardShortcut(",")
            Divider()
            Button("menu.quit".localized) {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        } label: {
            Image("StatusBarIcon")
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
