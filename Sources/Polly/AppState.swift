@MainActor
final class AppState {
  static let shared = AppState()
  var hotkeyManager: HotkeyManager?
}
