import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissionManager = PermissionManager()
    private let hotkeyListener = HotkeyListener()
    private let focusChecker = SlackFocusChecker()
    private let selectionProvider = SelectionProvider()
    private let overlayRenderer = OverlayRenderer()
    private let llmClient = LLMClient()
    private let resultApplier = ResultApplier()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !permissionManager.isTrusted() {
            AppState.shared.requestOpenSettings(tab: .permissions)
        }
        hotkeyListener.onHotkey = { [weak self] in
            self?.handleHotkey()
        }
        hotkeyListener.start()
    }

    private func handleHotkey() {
        do {
            let selection = try selectionProvider.getSelection()
            overlayRenderer.show(at: selection.bounds)
            llmClient.optimize(text: selection.text) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let optimized):
                        if case .failure = self?.resultApplier.apply(text: optimized) {
                            self?.overlayRenderer.showError(at: selection.bounds)
                        } else {
                            self?.overlayRenderer.hide()
                        }
                    case .failure(let error):
                        print("[Hotkey] LLM error: \(error)")
                        self?.overlayRenderer.showError(at: selection.bounds)
                    }
                }
            }
        } catch {
            print("[Hotkey] selection error: \(error)")
            if let selectionError = error as? SelectionError, selectionError == .notTrusted {
                AppState.shared.requestOpenSettings(tab: .permissions)
            } else {
                let mousePoint = NSEvent.mouseLocation
                overlayRenderer.showError(at: CGRect(origin: mousePoint, size: .zero))
            }
        }
    }
}
