import AppKit

final class ErrorIndicatorView: NSView {
  private let imageView = NSImageView()

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setupView()
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  private func setupView() {
    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    let image = NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: nil)
    imageView.image = image
    imageView.contentTintColor = .systemRed
    imageView.imageScaling = .scaleProportionallyDown
    imageView.frame = bounds
    imageView.autoresizingMask = [.width, .height]
    addSubview(imageView)
  }
}
