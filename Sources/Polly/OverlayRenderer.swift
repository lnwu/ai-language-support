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
  private var trackingTimer: Timer?
  private var lastMouseLocation: CGPoint?

  private let loadingSize = CGSize(width: 16, height: 16)
  private let errorSize = CGSize(width: 14, height: 14)
  private let offset = CGPoint(x: 14, y: 8)

  func show() {
    showOverlay(style: .loading)
  }

  func showError() {
    showOverlay(style: .error)
  }

  func hide() {
    hideTimer?.invalidate()
    hideTimer = nil
    stopMouseTracking()
    window?.orderOut(nil)
  }

  private func showOverlay(style: OverlayStyle) {
    hideTimer?.invalidate()

    let size = style == .loading ? loadingSize : errorSize
    let frame = CGRect(origin: originNearMouse(size: size), size: size)

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
        let indicator = NSProgressIndicator(frame: CGRect(origin: .zero, size: size))
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isIndeterminate = true
        indicator.startAnimation(nil)
        view = indicator
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

    if style == .loading {
      startMouseTracking(size: size)
    } else {
      stopMouseTracking()
      hideTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
        Task { @MainActor in
          self?.hide()
        }
      }
    }
  }

  private func originNearMouse(size: CGSize) -> CGPoint {
    let mouse = NSEvent.mouseLocation
    return CGPoint(x: mouse.x + offset.x, y: mouse.y - size.height - offset.y)
  }

  private func startMouseTracking(size: CGSize) {
    stopMouseTracking()
    lastMouseLocation = NSEvent.mouseLocation
    let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.window?.isVisible == true else { return }
        let mouse = NSEvent.mouseLocation
        guard mouse != self.lastMouseLocation else { return }
        self.lastMouseLocation = mouse
        self.window?.setFrameOrigin(self.originNearMouse(size: size))
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    trackingTimer = timer
  }

  private func stopMouseTracking() {
    trackingTimer?.invalidate()
    trackingTimer = nil
    lastMouseLocation = nil
  }
}
