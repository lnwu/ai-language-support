import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let selectionProvider = SelectionProvider()
  private let overlayRenderer = OverlayRenderer()
  private let llmClient = LLMClient()
  private let resultApplier = ResultApplier()
  private let hotkeyManager = HotkeyManager()
  private var isProcessing = false

  func applicationDidFinishLaunching(_ notification: Notification) {
    let hotkey = SettingsStore.shared.loadHotkey()
    hotkeyManager.onHotkey = { [weak self] in
      AppLogStore.shared.add(level: .info, category: "log.category.hotkey".localized, message: "log.hotkey.triggered".localized)
      self?.handleHotkey()
    }
    let didRegister = hotkeyManager.register(hotkey)
    if didRegister {
      AppLogStore.shared.add(level: .info, category: "log.category.hotkey".localized, message: "log.hotkey.registered".localized, detail: hotkey.display)
    } else {
      AppLogStore.shared.add(level: .error, category: "log.category.hotkey".localized, message: "log.hotkey.register_failed".localized, detail: hotkey.display)
    }
    AppState.shared.hotkeyManager = hotkeyManager
  }

  func applicationWillTerminate(_ notification: Notification) {
    hotkeyManager.unregister()
  }

  private func handleHotkey() {
    guard !isProcessing else {
      AppLogStore.shared.add(level: .warning, category: "log.category.process".localized, message: "log.process.in_progress".localized)
      return
    }
    isProcessing = true
    Task {
      defer { isProcessing = false }
      do {
        AppLogStore.shared.add(level: .info, category: "log.category.process".localized, message: "log.process.started".localized)

        let selection = try await selectionProvider.getSelection()
        AppLogStore.shared.add(level: .info, category: "log.category.selection".localized, message: "log.selection.success".localized, detail: selection.text)

        if let bounds = selection.bounds {
          overlayRenderer.show(at: bounds)
        }

        let optimized = try await llmClient.optimize(text: selection.text)
        AppLogStore.shared.add(level: .info, category: "log.category.llm".localized, message: "log.llm.success".localized)

        let applyResult = await resultApplier.apply(
          text: optimized,
          targetPid: selection.appPid,
          appBundleId: selection.appBundleId
        )

        if case .failure = applyResult {
          AppLogStore.shared.add(level: .error, category: "log.category.write".localized, message: "log.write.failed".localized)
          if let bounds = selection.bounds {
            overlayRenderer.showError(at: bounds)
          }
        } else {
          AppLogStore.shared.add(level: .info, category: "log.category.write".localized, message: "log.write.success".localized)
          overlayRenderer.hide()
        }
      } catch {
        AppLogStore.shared.add(level: .error, category: "log.category.process".localized, message: "log.process.failed".localized, detail: "\(error)")
        if let selectionError = error as? SelectionError {
          switch selectionError {
          case .notTrusted:
            return
          case .noSelection, .noFocusedElement:
            return
          case .boundsUnavailable:
            let mousePoint = NSEvent.mouseLocation
            overlayRenderer.showError(at: CGRect(origin: mousePoint, size: .zero))
          }
        } else {
          let mousePoint = NSEvent.mouseLocation
          overlayRenderer.showError(at: CGRect(origin: mousePoint, size: .zero))
        }
      }
    }
  }
}
