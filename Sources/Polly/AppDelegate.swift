import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let permissionManager = PermissionManager()
    private let selectionProvider = SelectionProvider()
    private let overlayRenderer = OverlayRenderer()
    private let llmClient = LLMClient()
    private let resultApplier = ResultApplier()
    private let hotkeyManager = HotkeyManager()
    private var isProcessing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !permissionManager.isTrusted() {
            AppState.shared.requestOpenSettings(tab: .permissions)
        }
        let hotkey = SettingsStore.shared.loadHotkey()
        hotkeyManager.onHotkey = { [weak self] in
            AppLogStore.shared.add(level: .info, category: "快捷键", message: "触发快捷键")
            self?.handleHotkey()
        }
        let didRegister = hotkeyManager.register(hotkey)
        if didRegister {
            AppLogStore.shared.add(level: .info, category: "快捷键", message: "注册成功", detail: hotkey.display)
        } else {
            AppLogStore.shared.add(level: .error, category: "快捷键", message: "注册失败", detail: hotkey.display)
        }
        AppState.shared.hotkeyManager = hotkeyManager
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.unregister()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        if AppState.shared.needsOpenSettings {
            DispatchQueue.main.async {
                AppState.shared.needsOpenSettings = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    AppState.shared.needsOpenSettings = true
                }
            }
        }
    }

    private func handleHotkey() {
        guard !isProcessing else {
            AppLogStore.shared.add(level: .warning, category: "流程", message: "上次处理尚未完成，跳过")
            return
        }
        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                AppLogStore.shared.add(level: .info, category: "流程", message: "开始处理")

                let selection = try await selectionProvider.getSelection()
                AppLogStore.shared.add(level: .info, category: "选区", message: "获取成功", detail: selection.text)

                if let bounds = selection.bounds {
                    overlayRenderer.show(at: bounds)
                }

                let optimized = try await llmClient.optimize(text: selection.text)
                AppLogStore.shared.add(level: .info, category: "LLM", message: "优化成功")

                let applyResult = await resultApplier.apply(
                    text: optimized,
                    targetPid: selection.appPid,
                    appBundleId: selection.appBundleId
                )

                if case .failure = applyResult {
                    AppLogStore.shared.add(level: .error, category: "写入", message: "写入失败")
                    if let bounds = selection.bounds {
                        overlayRenderer.showError(at: bounds)
                    }
                } else {
                    AppLogStore.shared.add(level: .info, category: "写入", message: "写入成功")
                    overlayRenderer.hide()
                }
            } catch {
                AppLogStore.shared.add(level: .error, category: "流程", message: "处理失败", detail: "\(error)")
                if let selectionError = error as? SelectionError {
                    switch selectionError {
                    case .notTrusted:
                        AppState.shared.requestOpenSettings(tab: .permissions)
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
