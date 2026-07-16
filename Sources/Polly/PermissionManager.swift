@preconcurrency import ApplicationServices

@MainActor
final class PermissionManager {
  func requestAccess() {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [promptKey: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  func isTrusted() -> Bool {
    AXIsProcessTrusted()
  }
}
