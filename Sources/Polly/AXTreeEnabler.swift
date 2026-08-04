import AppKit
import ApplicationServices

@MainActor
enum AXTreeEnabler {
  private static let retryInterval: UInt64 = 200_000_000
  private static let maxAttempts = 5

  static func enable(for element: AXUIElement) {
    var pid: pid_t = 0
    guard AXUIElementGetPid(element, &pid) == .success else { return }
    let appElement = AXUIElementCreateApplication(pid)
    AXUIElementSetAttributeValue(appElement, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    AXUIElementSetAttributeValue(appElement, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
  }

  static func retry<T>(_ operation: () async -> T?) async -> T? {
    for _ in 0..<maxAttempts {
      try? await Task.sleep(nanoseconds: retryInterval)
      if let value = await operation() {
        return value
      }
    }
    return nil
  }
}
