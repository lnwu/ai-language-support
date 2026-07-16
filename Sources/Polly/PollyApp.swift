import SwiftUI

@main
struct PollyApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @Environment(\.openSettings) private var openSettings

  var body: some Scene {
    MenuBarExtra {
      Button("menu.settings".localized) {
        openSettings()
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
}
