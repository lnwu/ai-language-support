import AppKit


@MainActor
final class OverlayRenderer {
    private enum OverlayStyle {
        case loading
        case error
    }

    private var window: NSPanel?
    private var hideTimer: Timer?
    private var currentStyle: OverlayStyle?

    private let loadingSize = CGSize(width: 15, height: 3)
    private let errorSize = CGSize(width: 14, height: 14)
    private let offset = CGPoint(x: 4, y: 1)

    func show(at rect: CGRect) {
        showOverlay(at: rect, style: .loading)
    }

    func showError(at rect: CGRect) {
        showOverlay(at: rect, style: .error)
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        window?.orderOut(nil)
    }

    private func showOverlay(at rect: CGRect, style: OverlayStyle) {
        hideTimer?.invalidate()

        let anchorRect: CGRect
        if rect.isNull || rect.isEmpty || rect.width <= 0 || rect.height <= 0 || !rect.origin.x.isFinite || !rect.origin.y.isFinite {
            let mouse = NSEvent.mouseLocation
            anchorRect = CGRect(origin: mouse, size: .zero)
        } else {
            anchorRect = rect
        }

        let size = style == .loading ? loadingSize : errorSize
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchorRect.origin) }) ?? NSScreen.main
        let screenFrame = screen?.frame ?? .zero
        let origin = CGPoint(
            x: anchorRect.maxX + offset.x,
            y: screenFrame.maxY - anchorRect.origin.y - size.height - offset.y
        )
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
            window = panel
        }

        if currentStyle != style || window?.contentView == nil {
            let view: NSView
            switch style {
            case .loading:
                view = LoadingDotsView(frame: CGRect(origin: .zero, size: size))
            case .error:
                view = ErrorIndicatorView(frame: CGRect(origin: .zero, size: size))
            }
            window?.contentView = view
            currentStyle = style
        } else {
            window?.contentView?.frame = CGRect(origin: .zero, size: size)
        }

        window?.setFrame(frame, display: true)
        window?.orderFront(nil)

        // Loading 不自动隐藏，由调用方控制
        if style == .error {
            hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.hide()
                }
            }
        }
    }
}
