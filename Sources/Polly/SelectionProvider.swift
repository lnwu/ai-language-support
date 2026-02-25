import AppKit
import ApplicationServices

struct TextSelection {
    let text: String
    let bounds: CGRect?
    let appPid: pid_t
    let appBundleId: String
}

enum SelectionError: Error {
    case notTrusted
    case noFocusedElement
    case noSelection
    case boundsUnavailable
}

extension SelectionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notTrusted:
            return "error.selection.not_trusted".localized
        case .noFocusedElement:
            return "error.selection.no_focused_element".localized
        case .noSelection:
            return "error.selection.no_selection".localized
        case .boundsUnavailable:
            return "error.selection.bounds_unavailable".localized
        }
    }
}

@MainActor
final class SelectionProvider {
    func getSelection() async throws -> TextSelection {
        guard AXIsProcessTrusted() else { throw SelectionError.notTrusted }

        let systemElement = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedResult == .success, let focusedElement = focused, CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
            throw SelectionError.noFocusedElement
        }
        let axElement = focusedElement as! AXUIElement

        let selectedText = try await resolveSelectedText(from: axElement)
        let rect = resolveSelectionBounds(from: axElement)
        let frontmost = NSWorkspace.shared.frontmostApplication
        let appPid = frontmost?.processIdentifier ?? 0
        let appBundleId = frontmost?.bundleIdentifier ?? ""
        return TextSelection(text: selectedText, bounds: rect, appPid: appPid, appBundleId: appBundleId)
    }

    private func resolveSelectedText(from element: AXUIElement) async throws -> String {
        var selectedTextValue: CFTypeRef?
        let selectedTextResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        if selectedTextResult == .success, let selectedText = selectedTextValue as? String, !selectedText.isEmpty {
            return selectedText
        }

        if let copied = await copySelection(), !copied.isEmpty {
            AppLogStore.log(level: .warning, category: "log.category.selection".localized, message: "log.selection.copy_fallback".localized)
            return copied
        }

        throw SelectionError.noSelection
    }

    private func resolveSelectionBounds(from element: AXUIElement) -> CGRect? {
        var selectedRangeValue: CFTypeRef?
        let selectedRangeResult = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue)
        guard selectedRangeResult == .success, let selectedRange = selectedRangeValue else {
            return nil
        }

        var boundsValue: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRange,
            &boundsValue
        )
        guard boundsResult == .success, let bounds = boundsValue, CFGetTypeID(bounds) == AXValueGetTypeID() else {
            return nil
        }
        let axValue = bounds as! AXValue

        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect) else {
            return nil
        }

        guard rect.width > 0 && rect.height > 0 else {
            return nil
        }

        return rect
    }

    private func copySelection() async -> String? {
        let pasteboard = NSPasteboard.general
        let existing = pasteboard.string(forType: .string)
        pasteboard.clearContents()

        let source = CGEventSource(stateID: .hidSystemState)
        let cKey: CGKeyCode = 0x08
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: true)
        cmdDown?.flags = .maskCommand
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cKey, keyDown: false)
        cmdUp?.flags = .maskCommand

        guard let cmdDown, let cmdUp else {
            restorePasteboard(existing)
            return nil
        }

        cmdDown.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)

        try? await Task.sleep(nanoseconds: 50_000_000)
        let copied = pasteboard.string(forType: .string)
        restorePasteboard(existing)
        return copied
    }

    private func restorePasteboard(_ existing: String?) {
        let pasteboard = NSPasteboard.general
        if let existing {
            pasteboard.clearContents()
            pasteboard.setString(existing, forType: .string)
        }
    }
}
