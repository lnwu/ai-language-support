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

    func applicationDidFinishLaunching(_ notification: Notification) {
        APILogStore.shared.clearAll()
        AppLogStore.clear()
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
        Task {
            do {
                AppLogStore.shared.add(level: .info, category: "流程", message: "开始处理")
                let selection = try await selectionProvider.getSelection()
                AppLogStore.shared.add(level: .info, category: "选区", message: "获取成功", detail: selection.text)
                overlayRenderer.show(at: selection.bounds)
                llmClient.optimize(text: selection.text) { [weak self] result in
                    Task { @MainActor in
                        switch result {
                        case .success(let optimized):
                            AppLogStore.shared.add(level: .info, category: "LLM", message: "优化成功")
                            let forcePasteBundleIds = ["com.tinyspeck.slackmacgap", "com.apple.Notes"]
                            let applyResult: Result<Void, Error>?
                            if forcePasteBundleIds.contains(selection.appBundleId) {
                                applyResult = await self?.resultApplier.forcePaste(text: optimized, targetPid: selection.appPid)
                            } else {
                                applyResult = await self?.resultApplier.apply(text: optimized, targetPid: selection.appPid)
                            }
                            if case .failure = applyResult {
                                AppLogStore.shared.add(level: .error, category: "写入", message: "写入失败")
                                self?.overlayRenderer.showError(at: selection.bounds)
                            } else {
                                AppLogStore.shared.add(level: .info, category: "写入", message: "写入成功")
                                self?.overlayRenderer.hide()
                            }
                        case .failure(let error):
                            print("[Hotkey] LLM error: \(error)")
                            AppLogStore.shared.add(level: .error, category: "LLM", message: "优化失败", detail: "\(error)")
                            self?.overlayRenderer.showError(at: selection.bounds)
                        }
                    }
                }
            } catch {
                print("[Hotkey] selection error: \(error)")
                AppLogStore.shared.add(level: .error, category: "选区", message: "获取失败", detail: "\(error)")
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
