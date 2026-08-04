import AppKit
import ApplicationServices

struct TextSelection {
  let text: String
  let appPid: pid_t
}

enum SelectionError: Error {
  case notTrusted
  case noFocusedElement
  case noSelection
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
    }
  }
}

@MainActor
final class SelectionProvider {
  func getSelection() async throws -> TextSelection {
    guard AXIsProcessTrusted() else { throw SelectionError.notTrusted }
    guard let initialElement = Self.focusedElement() else {
      throw SelectionError.noFocusedElement
    }

    var selectedText = Self.selectedText(from: initialElement)

    if selectedText == nil {
      AXTreeEnabler.enable(for: initialElement)
      AppLogStore.log(level: .warning, category: "log.category.selection".localized, message: "log.selection.ax_tree_retry".localized)
      let resolved: String? = await AXTreeEnabler.retry({
        guard let element = Self.focusedElement() else {
          return nil
        }
        return Self.selectedText(from: element)
      })
      selectedText = resolved
    }

    guard let text = selectedText, !text.isEmpty else {
      throw SelectionError.noSelection
    }

    let appPid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
    return TextSelection(text: text, appPid: appPid)
  }

  static func focusedElement() -> AXUIElement? {
    let systemElement = AXUIElementCreateSystemWide()
    var focused: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focused)
    guard result == .success, let focusedElement = focused, CFGetTypeID(focusedElement) == AXUIElementGetTypeID() else {
      return nil
    }
    return (focusedElement as! AXUIElement)
  }

  private static func selectedText(from element: AXUIElement) -> String? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
    guard result == .success, let text = value as? String, !text.isEmpty else {
      return nil
    }
    return text
  }
}
