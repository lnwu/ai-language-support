import AppKit

final class LoadingDotsView: NSView {
    private let dotCount = 3
    private let dotSize: CGFloat = 3
    private let dotSpacing: CGFloat = 3
    private var dotLayers: [CALayer] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupLayers()
        startAnimation()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupLayers()
        startAnimation()
    }

    private func setupLayers() {
        dotLayers.forEach { $0.removeFromSuperlayer() }
        dotLayers = []

        for index in 0..<dotCount {
            let dotLayer = CALayer()
            dotLayer.backgroundColor = NSColor.labelColor.cgColor
            dotLayer.cornerRadius = dotSize / 2
            dotLayer.frame = CGRect(
                x: CGFloat(index) * (dotSize + dotSpacing),
                y: 0,
                width: dotSize,
                height: dotSize
            )
            layer?.addSublayer(dotLayer)
            dotLayers.append(dotLayer)
        }
    }

    private func startAnimation() {
        for (index, dotLayer) in dotLayers.enumerated() {
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0.2
            opacity.toValue = 1.0
            opacity.duration = 0.6
            opacity.autoreverses = true
            opacity.repeatCount = .infinity
            opacity.beginTime = CACurrentMediaTime() + Double(index) * 0.2
            opacity.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dotLayer.add(opacity, forKey: "opacityPulse")

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.85
            scale.toValue = 1.2
            scale.duration = 0.6
            scale.autoreverses = true
            scale.repeatCount = .infinity
            scale.beginTime = CACurrentMediaTime() + Double(index) * 0.2
            scale.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            dotLayer.add(scale, forKey: "scalePulse")
        }
    }
}
