import AppKit
import ApplicationServices

enum ResultApplierError: Error {
    case axWriteFailed
    case pasteFailed
}

final class ResultApplier {
    func apply(text: String) -> Result<Void, Error> {
        let systemElement = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedResult == .success, let focusedElement = focused else {
            return copyAndPaste(text: text)
        }

        let setResult = AXUIElementSetAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        if setResult != .success {
            return copyAndPaste(text: text)
        }
        return .success(())
    }

    private func copyAndPaste(text: String) -> Result<Void, Error> {
        let pasteboard = NSPasteboard.general
        let existing = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 0x09
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        cmdDown?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        cmdUp?.flags = .maskCommand

        guard let cmdDown, let cmdUp else {
            restorePasteboard(existing)
            return .failure(ResultApplierError.pasteFailed)
        }

        cmdDown.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)

        restorePasteboard(existing)
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
