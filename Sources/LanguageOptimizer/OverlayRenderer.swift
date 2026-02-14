import AppKit

@MainActor
final class OverlayRenderer {
    private var window: NSPanel?
    private var hideTimer: Timer?

    func show(at rect: CGRect) {
        hideTimer?.invalidate()

        let size = CGSize(width: 44, height: 12)
        let origin = CGPoint(x: rect.maxX + 6, y: rect.maxY + 6)
        let frame = CGRect(origin: origin, size: size)

        if window == nil {
            let panel = NSPanel(
                contentRect: frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]

            let view = LoadingDotsView(frame: CGRect(origin: .zero, size: size))
            panel.contentView = view
            window = panel
        }

        window?.setFrame(frame, display: true)
        window?.orderFront(nil)

        hideTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.hide()
            }
        }
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        window?.orderOut(nil)
    }
}
