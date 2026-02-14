import AppKit

final class SlackFocusChecker {
    private let slackBundleId = "com.tinyspeck.slackmacgap"

    func isSlackFocused() -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return false }
        return frontmost.bundleIdentifier == slackBundleId
    }
}
