import AppKit
import Carbon
import Carbon.HIToolbox

struct Hotkey: Equatable {
  let keyCode: UInt32
  let modifiers: NSEvent.ModifierFlags
  let display: String

  var carbonModifiers: UInt32 {
    var value: UInt32 = 0
    if modifiers.contains(.command) { value |= UInt32(cmdKey) }
    if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
    if modifiers.contains(.option) { value |= UInt32(optionKey) }
    if modifiers.contains(.control) { value |= UInt32(controlKey) }
    return value
  }

  static func `default`() -> Hotkey {
    Hotkey(keyCode: UInt32(kVK_ANSI_R), modifiers: [.command, .shift], display: "⇧⌘R")
  }

  static func build(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, displayKey: String?) -> Hotkey {
    let normalized = modifiers.intersection(.deviceIndependentFlagsMask)
    let key = displayKey?.isEmpty == false ? displayKey! : keyName(for: keyCode)
    let display = displayString(modifiers: normalized, key: key)
    return Hotkey(keyCode: UInt32(keyCode), modifiers: normalized, display: display)
  }

  static func displayString(modifiers: NSEvent.ModifierFlags, key: String) -> String {
    var pieces: [String] = []
    if modifiers.contains(.control) { pieces.append("⌃") }
    if modifiers.contains(.option) { pieces.append("⌥") }
    if modifiers.contains(.shift) { pieces.append("⇧") }
    if modifiers.contains(.command) { pieces.append("⌘") }
    pieces.append(key.uppercased())
    return pieces.joined()
  }

  static func isModifierKeyCode(_ keyCode: UInt16) -> Bool {
    switch keyCode {
    case UInt16(kVK_Command), UInt16(kVK_Shift), UInt16(kVK_Option), UInt16(kVK_Control),
      UInt16(kVK_RightCommand), UInt16(kVK_RightShift), UInt16(kVK_RightOption), UInt16(kVK_RightControl):
      return true
    default:
      return false
    }
  }

  static func keyName(for keyCode: UInt16) -> String {
    if let translated = translatedKeyName(for: keyCode) {
      return translated
    }
    switch keyCode {
    case UInt16(kVK_ANSI_A): return "A"
    case UInt16(kVK_ANSI_B): return "B"
    case UInt16(kVK_ANSI_C): return "C"
    case UInt16(kVK_ANSI_D): return "D"
    case UInt16(kVK_ANSI_E): return "E"
    case UInt16(kVK_ANSI_F): return "F"
    case UInt16(kVK_ANSI_G): return "G"
    case UInt16(kVK_ANSI_H): return "H"
    case UInt16(kVK_ANSI_I): return "I"
    case UInt16(kVK_ANSI_J): return "J"
    case UInt16(kVK_ANSI_K): return "K"
    case UInt16(kVK_ANSI_L): return "L"
    case UInt16(kVK_ANSI_M): return "M"
    case UInt16(kVK_ANSI_N): return "N"
    case UInt16(kVK_ANSI_O): return "O"
    case UInt16(kVK_ANSI_P): return "P"
    case UInt16(kVK_ANSI_Q): return "Q"
    case UInt16(kVK_ANSI_R): return "R"
    case UInt16(kVK_ANSI_S): return "S"
    case UInt16(kVK_ANSI_T): return "T"
    case UInt16(kVK_ANSI_U): return "U"
    case UInt16(kVK_ANSI_V): return "V"
    case UInt16(kVK_ANSI_W): return "W"
    case UInt16(kVK_ANSI_X): return "X"
    case UInt16(kVK_ANSI_Y): return "Y"
    case UInt16(kVK_ANSI_Z): return "Z"
    case UInt16(kVK_ANSI_0): return "0"
    case UInt16(kVK_ANSI_1): return "1"
    case UInt16(kVK_ANSI_2): return "2"
    case UInt16(kVK_ANSI_3): return "3"
    case UInt16(kVK_ANSI_4): return "4"
    case UInt16(kVK_ANSI_5): return "5"
    case UInt16(kVK_ANSI_6): return "6"
    case UInt16(kVK_ANSI_7): return "7"
    case UInt16(kVK_ANSI_8): return "8"
    case UInt16(kVK_ANSI_9): return "9"
    case UInt16(kVK_Space): return "Space"
    case UInt16(kVK_Return): return "Return"
    case UInt16(kVK_Delete): return "Delete"
    case UInt16(kVK_Escape): return "Esc"
    case UInt16(kVK_Tab): return "Tab"
    default: return "?"
    }
  }

  private static func translatedKeyName(for keyCode: UInt16) -> String? {
    guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue() else {
      return nil
    }
    guard let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
      return nil
    }
    let data = unsafeBitCast(layoutData, to: CFData.self)
    guard let dataPtr = CFDataGetBytePtr(data) else {
      return nil
    }
    let keyLayout = dataPtr.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 }
    var deadKeyState: UInt32 = 0
    var length: Int = 0
    var unicode = [UniChar](repeating: 0, count: 4)
    let status = UCKeyTranslate(
      keyLayout,
      keyCode,
      UInt16(kUCKeyActionDisplay),
      0,
      UInt32(LMGetKbdType()),
      OptionBits(kUCKeyTranslateNoDeadKeysMask),
      &deadKeyState,
      unicode.count,
      &length,
      &unicode
    )
    guard status == noErr, length > 0 else {
      return nil
    }
    return String(utf16CodeUnits: unicode, count: length)
  }
}
