import AppKit

@MainActor
final class HotkeyListener {
    var onHotkey: (() -> Void)?
    private var globalMonitor: Any?

    func start() {
        guard globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.contains(.command) else { return }
            guard event.charactersIgnoringModifiers?.lowercased() == "e" else { return }
            Task { @MainActor in
                self?.onHotkey?()
            }
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }
}
