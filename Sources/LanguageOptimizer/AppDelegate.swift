import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindowController: NSWindowController?
    private let permissionManager = PermissionManager()
    private let hotkeyListener = HotkeyListener()
    private let focusChecker = SlackFocusChecker()
    private let selectionProvider = SelectionProvider()
    private let overlayRenderer = OverlayRenderer()
    private let llmClient = LLMClient()
    private let resultApplier = ResultApplier()
    private let notifier = NotificationPresenter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        permissionManager.promptIfNeededOnLaunch()
        notifier.requestAuthorization()
        hotkeyListener.onHotkey = { [weak self] in
            self?.handleHotkey()
        }
        hotkeyListener.start()
    }


    private func setupStatusItem() {
        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let image = NSImage(named: "StatusBarIcon")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageOnly
            button.action = #selector(handleStatusItemClick)
            button.target = self
        }
    }

    @objc
    private func handleStatusItemClick() {
        let menu = NSMenu()
        menu.showsStateColumn = false

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.image = nil
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc
    private func openSettings() {
        if settingsWindowController == nil {
            let view = SettingsView()
            let hosting = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: hosting)
            window.title = "Settings"
            window.setContentSize(NSSize(width: 520, height: 360))
            window.styleMask = NSWindow.StyleMask([.titled, .closable, .miniaturizable])
            window.isReleasedWhenClosed = false
            settingsWindowController = NSWindowController(window: window)
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }


    private func handleHotkey() {
        guard focusChecker.isSlackFocused() else { return }
        do {
            let selection = try selectionProvider.getSelection()
            overlayRenderer.show(at: selection.bounds)
            llmClient.optimize(text: selection.text) { [weak self] result in
                DispatchQueue.main.async {
                    self?.overlayRenderer.hide()
                    switch result {
                    case .success(let optimized):
                        if case .failure = self?.resultApplier.apply(text: optimized) {
                            self?.notifier.showError(message: "替换失败，内容已在剪贴板")
                        }
                    case .failure(let error):
                        self?.notifier.showError(message: error.localizedDescription)
                    }
                }
            }
        } catch {
            notifier.showError(message: error.localizedDescription)
        }
    }
}
