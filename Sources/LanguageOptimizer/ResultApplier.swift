import AppKit
import ApplicationServices

enum ResultApplierError: Error {
    case axWriteFailed
    case pasteFailed
}

final class ResultApplier {
    func apply(text: String, targetPid: pid_t? = nil) -> Result<Void, Error> {
        let systemElement = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedResult == .success, let focusedElement = focused else {
            AppLogStore.log(level: .warning, category: "写入", message: "未获取焦点，走粘贴兜底")
            return copyAndPaste(text: text, targetPid: targetPid)
        }

        let setResult = AXUIElementSetAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        if setResult == .success {
            return .success(())
        }
        AppLogStore.log(level: .warning, category: "写入", message: "AX 写入失败，走粘贴兜底")
        return copyAndPaste(text: text, targetPid: targetPid)
    }

    func forcePaste(text: String, targetPid: pid_t?) -> Result<Void, Error> {
        return copyAndPaste(text: text, targetPid: targetPid, force: true)
    }

    private func copyAndPaste(text: String, targetPid: pid_t?, force: Bool = false) -> Result<Void, Error> {
        let pasteboard = NSPasteboard.general
        let existing = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if let targetPid, let app = NSRunningApplication(processIdentifier: targetPid) {
            app.activate(options: [.activateAllWindows])
        }

        let source = CGEventSource(stateID: .combinedSessionState)
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

        Thread.sleep(forTimeInterval: 0.05)
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
