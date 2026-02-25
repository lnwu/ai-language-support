import AppKit
import ApplicationServices

enum ResultApplierError: Error {
    case axWriteFailed
    case pasteFailed
}

@MainActor
final class ResultApplier {
    private static let forcePasteBundleIds: Set<String> = [
        "com.tinyspeck.slackmacgap",
        "com.apple.Notes",
        "com.google.Chrome",
    ]

    private static let pasteDelay: UInt64 = 200_000_000
    private static let slowAppPasteDelay: UInt64 = 500_000_000

    func apply(text: String, targetPid: pid_t? = nil, appBundleId: String = "") async -> Result<Void, Error> {
        let isSlowApp = Self.forcePasteBundleIds.contains(appBundleId)
        if isSlowApp {
            return await copyAndPaste(text: text, targetPid: targetPid, appBundleId: appBundleId, force: true)
        }

        let systemElement = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedResult == .success, let focusedElement = focused, CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            AppLogStore.log(level: .warning, category: "写入", message: "未获取焦点，走粘贴兜底")
            return await copyAndPaste(text: text, targetPid: targetPid, appBundleId: appBundleId)
        }

        let axElement = focusedElement as! AXUIElement
        let setResult = AXUIElementSetAttributeValue(axElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        if setResult == .success {
            return .success(())
        }
        AppLogStore.log(level: .warning, category: "写入", message: "AX 写入失败，走粘贴兜底")
        return await copyAndPaste(text: text, targetPid: targetPid, appBundleId: appBundleId)
    }

    private func copyAndPaste(text: String, targetPid: pid_t?, appBundleId: String = "", force: Bool = false) async -> Result<Void, Error> {
        let pasteboard = NSPasteboard.general
        let existing = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if let targetPid, let app = NSRunningApplication(processIdentifier: targetPid) {
            app.activate(options: [.activateAllWindows])
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let vKey: CGKeyCode = 0x09
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        cmdDown?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        cmdUp?.flags = .maskCommand

        guard let cmdDown, let cmdUp else {
            restorePasteboard(existing)
            AppLogStore.log(level: .error, category: "写入", message: "粘贴失败")
            return .failure(ResultApplierError.pasteFailed)
        }

        cmdDown.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)

        let delay = Self.forcePasteBundleIds.contains(appBundleId) ? Self.slowAppPasteDelay : Self.pasteDelay
        try? await Task.sleep(nanoseconds: delay)
        restorePasteboard(existing)
        AppLogStore.log(level: .info, category: "写入", message: force ? "强制粘贴成功" : "粘贴成功")
        return .success(())
    }

    private func restorePasteboard(_ existing: String?) {
        let pasteboard = NSPasteboard.general
        if let existing {
            pasteboard.clearContents()
            pasteboard.setString(existing, forType: .string)
        }
    }
}
