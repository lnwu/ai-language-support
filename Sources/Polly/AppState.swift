import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()
    @Published var needsOpenSettings = false
    var hotkeyManager: HotkeyManager?

    func requestOpenSettings(tab: SettingsTab = .general) {
        UserDefaults.standard.set(tab.rawValue, forKey: "selectedSettingsTab")
        needsOpenSettings = true
    }
}
