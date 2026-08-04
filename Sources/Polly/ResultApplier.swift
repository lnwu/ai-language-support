import AppKit
import ApplicationServices

enum ResultApplierError: Error {
  case noFocusedElement
  case focusChanged
  case writeFailed
}

@MainActor
final class ResultApplier {
  private enum WriteStrategy {
    case selectedText
    case value
    case typing
  }

  private struct Snapshot {
    let value: String
    let range: CFRange

    func expected(afterInserting text: String) -> String? {
      let nsValue = value as NSString
      guard range.location >= 0, range.length >= 0, range.location + range.length <= nsValue.length else {
        return nil
      }
      return nsValue.replacingCharacters(in: NSRange(location: range.location, length: range.length), with: text)
    }
  }

  private var strategyCache: [String: WriteStrategy] = [:]

  func apply(text: String, targetPid: pid_t? = nil) async -> Result<Void, Error> {
    guard let element = SelectionProvider.focusedElement() else {
      AppLogStore.log(level: .error, category: "log.category.write".localized, message: "log.write.no_focus".localized)
      return .failure(ResultApplierError.noFocusedElement)
    }

    if let targetPid, !Self.matches(element: element, pid: targetPid) {
      AppLogStore.log(level: .error, category: "log.category.write".localized, message: "log.write.focus_changed".localized)
      return .failure(ResultApplierError.focusChanged)
    }

    let bundleId = targetPid.flatMap { NSRunningApplication(processIdentifier: $0)?.bundleIdentifier }

    if let bundleId, let cached = strategyCache[bundleId] {
      if await Self.execute(cached, text: text, on: element, targetPid: targetPid) {
        return .success(())
      }
      strategyCache.removeValue(forKey: bundleId)
      AppLogStore.log(level: .warning, category: "log.category.write".localized, message: "log.write.cached_strategy_failed".localized)
    }

    if await Self.writeViaSelectedText(text: text, to: element) {
      cache(.selectedText, for: bundleId)
      return .success(())
    }

    if await Self.writeViaValueReplacement(text: text, to: element) {
      cache(.value, for: bundleId)
      return .success(())
    }

    AXTreeEnabler.enable(for: element)
    AppLogStore.log(level: .warning, category: "log.category.write".localized, message: "log.write.ax_tree_retry".localized)
    let retried: WriteStrategy? = await AXTreeEnabler.retry {
      guard let retryElement = SelectionProvider.focusedElement() else { return nil }
      if let targetPid, !Self.matches(element: retryElement, pid: targetPid) { return nil }
      if await Self.writeViaSelectedText(text: text, to: retryElement) { return .selectedText }
      if await Self.writeViaValueReplacement(text: text, to: retryElement) { return .value }
      return nil
    }
    if let retried {
      cache(retried, for: bundleId)
      return .success(())
    }

    if await Self.writeViaTyping(text: text, targetPid: targetPid) {
      AppLogStore.log(level: .info, category: "log.category.write".localized, message: "log.write.typing_fallback".localized)
      cache(.typing, for: bundleId)
      return .success(())
    }

    AppLogStore.log(level: .error, category: "log.category.write".localized, message: "log.write.ax_failed".localized)
    return .failure(ResultApplierError.writeFailed)
  }

  private func cache(_ strategy: WriteStrategy, for bundleId: String?) {
    guard let bundleId else { return }
    strategyCache[bundleId] = strategy
  }

  private static func execute(_ strategy: WriteStrategy, text: String, on element: AXUIElement, targetPid: pid_t?) async -> Bool {
    switch strategy {
    case .selectedText:
      return await writeViaSelectedText(text: text, to: element)
    case .value:
      return await writeViaValueReplacement(text: text, to: element)
    case .typing:
      return await writeViaTyping(text: text, targetPid: targetPid)
    }
  }

  private static func writeViaSelectedText(text: String, to element: AXUIElement) async -> Bool {
    let snapshot = snapshot(of: element)
    guard setSelectedText(text, on: element) else { return false }
    guard let snapshot, let expected = snapshot.expected(afterInserting: text) else {
      return true
    }
    return await verify(element: element, expected: expected)
  }

  private static func writeViaValueReplacement(text: String, to element: AXUIElement) async -> Bool {
    guard let snapshot = snapshot(of: element),
          let expected = snapshot.expected(afterInserting: text),
          setValue(expected, on: element),
          await verify(element: element, expected: expected) else {
      return false
    }

    var caret = CFRange(location: snapshot.range.location + (text as NSString).length, length: 0)
    if let caretValue = AXValueCreate(.cfRange, &caret) {
      AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, caretValue)
    }
    AppLogStore.log(level: .info, category: "log.category.write".localized, message: "log.write.value_fallback".localized)
    return true
  }

  private static func verify(element: AXUIElement, expected: String) async -> Bool {
    let normalizedExpected = normalize(expected)
    for attempt in 0..<10 {
      if attempt > 0 {
        try? await Task.sleep(nanoseconds: 150_000_000)
      }
      if let value = readValue(from: element), normalize(value) == normalizedExpected {
        return true
      }
    }
    return false
  }

  private static func normalize(_ string: String) -> String {
    string.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func writeViaTyping(text: String, targetPid: pid_t?) async -> Bool {
    guard let element = SelectionProvider.focusedElement() else { return false }
    if let targetPid, !matches(element: element, pid: targetPid) { return false }
    let snapshot = snapshot(of: element)

    let source = CGEventSource(stateID: .hidSystemState)
    let characters = Array(text)
    let chunkSize = 10
    var index = 0
    while index < characters.count {
      let end = min(index + chunkSize, characters.count)
      var units = Array(String(characters[index..<end]).utf16)
      guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
        return false
      }
      units.withUnsafeBufferPointer { buffer in
        guard let base = buffer.baseAddress else { return }
        keyDown.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
        keyUp.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
      }
      keyDown.post(tap: .cghidEventTap)
      keyUp.post(tap: .cghidEventTap)
      index = end
      usleep(2000)
    }

    guard let snapshot, let expected = snapshot.expected(afterInserting: text) else {
      return true
    }
    guard let currentElement = SelectionProvider.focusedElement() else { return false }
    return await verify(element: currentElement, expected: expected)
  }

  private static func setSelectedText(_ text: String, on element: AXUIElement) -> Bool {
    AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
  }

  private static func setValue(_ value: String, on element: AXUIElement) -> Bool {
    AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, value as CFTypeRef) == .success
  }

  private static func readValue(from element: AXUIElement) -> String? {
    var valueRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success else {
      return nil
    }
    return valueRef as? String
  }

  private static func snapshot(of element: AXUIElement) -> Snapshot? {
    guard let value = readValue(from: element) else { return nil }
    var rangeRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
          let rangeRaw = rangeRef, CFGetTypeID(rangeRaw) == AXValueGetTypeID() else {
      return nil
    }
    var range = CFRange()
    guard AXValueGetValue((rangeRaw as! AXValue), .cfRange, &range) else {
      return nil
    }
    return Snapshot(value: value, range: range)
  }

  private static func matches(element: AXUIElement, pid: pid_t) -> Bool {
    var elementPid: pid_t = 0
    guard AXUIElementGetPid(element, &elementPid) == .success else { return false }
    return elementPid == pid
  }
}
