import ApplicationServices

struct TextSelection {
    let text: String
    let bounds: CGRect
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
            return "未获得辅助功能权限"
        case .noFocusedElement:
            return "未检测到可编辑输入框"
        case .noSelection:
            return "未检测到选中文本"
        case .boundsUnavailable:
            return "无法定位选区"
        }
    }
}

final class SelectionProvider {
    func getSelection() throws -> TextSelection {
        guard AXIsProcessTrusted() else { throw SelectionError.notTrusted }

        let systemElement = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focused)
        guard focusedResult == .success, let focusedElement = focused else {
            throw SelectionError.noFocusedElement
        }

        var selectedTextValue: CFTypeRef?
        let selectedTextResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
        guard selectedTextResult == .success, let selectedText = selectedTextValue as? String, !selectedText.isEmpty else {
            throw SelectionError.noSelection
        }

        var selectedRangeValue: CFTypeRef?
        let selectedRangeResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue)
        guard selectedRangeResult == .success, let selectedRange = selectedRangeValue else {
            throw SelectionError.noSelection
        }

        var boundsValue: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            focusedElement as! AXUIElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            selectedRange,
            &boundsValue
        )
        guard boundsResult == .success, let bounds = boundsValue else {
            throw SelectionError.boundsUnavailable
        }

        var rect = CGRect.zero
        if !AXValueGetValue(bounds as! AXValue, .cgRect, &rect) {
            throw SelectionError.boundsUnavailable
        }

        return TextSelection(text: selectedText, bounds: rect)
    }
}
