import AppKit
import Carbon

final class HotkeyManager {
    var onHotkey: (() -> Void)?
    private var hotkeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var currentHotkey: Hotkey?

    func register(_ hotkey: Hotkey) -> Bool {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let eventTarget = GetEventDispatcherTarget()

        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(eventTarget, { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onHotkey?()
            return noErr
        }, 1, &eventType, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()), &handlerRef)

        guard status == noErr else {
            AppLogStore.log(level: .error, category: "快捷键", message: "监听安装失败", detail: "\(status)")
            return false
        }
        handler = handlerRef

        let hotKeyID = EventHotKeyID(signature: OSType(0x4c6f486b), id: 1)
        var ref: EventHotKeyRef?
        let registerStatus = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.carbonModifiers,
            hotKeyID,
            eventTarget,
            0,
            &ref
        )
        if registerStatus == noErr {
            hotkeyRef = ref
            currentHotkey = hotkey
            return true
        }
        AppLogStore.log(level: .error, category: "快捷键", message: "注册失败", detail: "\(registerStatus)")
        return false
    }

    func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
            self.hotkeyRef = nil
        }
        if let handler {
            RemoveEventHandler(handler)
            self.handler = nil
        }
        currentHotkey = nil
    }

    func isRegistered(_ hotkey: Hotkey) -> Bool {
        currentHotkey == hotkey && hotkeyRef != nil
    }
}
