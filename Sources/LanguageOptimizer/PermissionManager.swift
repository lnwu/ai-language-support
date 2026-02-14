@preconcurrency import ApplicationServices
import AppKit

@MainActor
final class PermissionManager {
    func promptIfNeededOnLaunch() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
