import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let selectionProvider = SelectionProvider()
  private let overlayRenderer = OverlayRenderer()
  private let llmClient = LLMClient()
  private let resultApplier = ResultApplier()
  private let hotkeyManager = HotkeyManager()
  private var processingTask: Task<Void, Never>?

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
    if let processingTask {
      processingTask.cancel()
      self.processingTask = nil
      overlayRenderer.hide()
      AppLogStore.shared.add(level: .info, category: "log.category.process".localized, message: "log.process.cancelled".localized)
      return
    }

    let task = Task { [weak self] in
      guard let self else { return }
      defer { self.processingTask = nil }
      do {
        AppLogStore.shared.add(level: .info, category: "log.category.process".localized, message: "log.process.started".localized)

        let selection = try await selectionProvider.getSelection()
        try Task.checkCancellation()
        AppLogStore.shared.add(level: .info, category: "log.category.selection".localized, message: "log.selection.success".localized, detail: selection.text)

        overlayRenderer.show()

        let optimized = try await llmClient.optimize(text: selection.text)
        try Task.checkCancellation()
        AppLogStore.shared.add(level: .info, category: "log.category.llm".localized, message: "log.llm.success".localized)

        let applyResult = await resultApplier.apply(
          text: optimized,
          targetPid: selection.appPid
        )

        guard !Task.isCancelled else { return }

        if case .failure = applyResult {
          AppLogStore.shared.add(level: .error, category: "log.category.write".localized, message: "log.write.failed".localized)
          overlayRenderer.showError()
        } else {
          AppLogStore.shared.add(level: .info, category: "log.category.write".localized, message: "log.write.success".localized)
          overlayRenderer.hide()
        }
      } catch is CancellationError {
        // 取消路径已在 handleHotkey 中隐藏浮层并记录日志
      } catch {
        AppLogStore.shared.add(level: .error, category: "log.category.process".localized, message: "log.process.failed".localized, detail: "\(error)")
        overlayRenderer.showError()
      }
    }
    processingTask = task
  }
}
