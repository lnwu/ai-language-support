import XCTest
import AppKit
import Carbon.HIToolbox
@testable import Polly

final class HotkeyTests: XCTestCase {
  func testDisplayStringModifierOrder() {
    let display = Hotkey.displayString(modifiers: [.command, .shift, .option, .control], key: "r")
    XCTAssertEqual(display, "⌃⌥⇧⌘R")
  }

  func testDisplayStringUppercasesKey() {
    XCTAssertEqual(Hotkey.displayString(modifiers: [.command], key: "a"), "⌘A")
  }

  func testCarbonModifiersMapping() {
    let hotkey = Hotkey(keyCode: 0, modifiers: [.command, .shift], display: "")
    XCTAssertEqual(hotkey.carbonModifiers, UInt32(cmdKey | shiftKey))

    let none = Hotkey(keyCode: 0, modifiers: [], display: "")
    XCTAssertEqual(none.carbonModifiers, 0)
  }

  func testIsModifierKeyCode() {
    XCTAssertTrue(Hotkey.isModifierKeyCode(UInt16(kVK_Command)))
    XCTAssertTrue(Hotkey.isModifierKeyCode(UInt16(kVK_Shift)))
    XCTAssertTrue(Hotkey.isModifierKeyCode(UInt16(kVK_Option)))
    XCTAssertTrue(Hotkey.isModifierKeyCode(UInt16(kVK_Control)))
    XCTAssertTrue(Hotkey.isModifierKeyCode(UInt16(kVK_RightCommand)))
    XCTAssertTrue(Hotkey.isModifierKeyCode(UInt16(kVK_RightShift)))
    XCTAssertTrue(Hotkey.isModifierKeyCode(UInt16(kVK_RightOption)))
    XCTAssertTrue(Hotkey.isModifierKeyCode(UInt16(kVK_RightControl)))
    XCTAssertFalse(Hotkey.isModifierKeyCode(UInt16(kVK_ANSI_R)))
    XCTAssertFalse(Hotkey.isModifierKeyCode(UInt16(kVK_Space)))
  }

  func testBuildPrefersDisplayKey() {
    let hotkey = Hotkey.build(keyCode: UInt16(kVK_ANSI_R), modifiers: [.command, .shift], displayKey: "R")
    XCTAssertEqual(hotkey.display, "⇧⌘R")
    XCTAssertEqual(hotkey.keyCode, UInt32(kVK_ANSI_R))
    XCTAssertEqual(hotkey.modifiers, [.command, .shift])
  }

  func testBuildFallsBackToKeyNameWhenDisplayKeyMissing() {
    let hotkey = Hotkey.build(keyCode: UInt16(kVK_ANSI_R), modifiers: [.command], displayKey: nil)
    XCTAssertEqual(hotkey.keyCode, UInt32(kVK_ANSI_R))
    XCTAssertFalse(hotkey.display.isEmpty)
  }

  func testBuildStripsDeviceDependentFlags() {
    let raw = NSEvent.ModifierFlags(rawValue: 0x100001)
    let hotkey = Hotkey.build(keyCode: UInt16(kVK_ANSI_R), modifiers: raw, displayKey: "R")
    XCTAssertEqual(hotkey.modifiers, [.command])
  }

  func testDefaultHotkey() {
    let hotkey = Hotkey.default()
    XCTAssertEqual(hotkey.keyCode, UInt32(kVK_ANSI_R))
    XCTAssertEqual(hotkey.modifiers, [.command, .shift])
    XCTAssertEqual(hotkey.display, "⇧⌘R")
  }
}

final class SnapshotTests: XCTestCase {
  func testExpectedReplacesSelectedRange() {
    let snapshot = ResultApplier.Snapshot(value: "hello world", range: CFRange(location: 6, length: 5))
    XCTAssertEqual(snapshot.expected(afterInserting: "polly"), "hello polly")
  }

  func testExpectedInsertsAtEmptyRange() {
    let snapshot = ResultApplier.Snapshot(value: "helloworld", range: CFRange(location: 5, length: 0))
    XCTAssertEqual(snapshot.expected(afterInserting: " "), "hello world")
  }

  func testExpectedReturnsNilWhenRangeOutOfBounds() {
    let snapshot = ResultApplier.Snapshot(value: "abc", range: CFRange(location: 2, length: 5))
    XCTAssertNil(snapshot.expected(afterInserting: "x"))
  }

  func testExpectedReturnsNilWhenLocationNegative() {
    let snapshot = ResultApplier.Snapshot(value: "abc", range: CFRange(location: -1, length: 1))
    XCTAssertNil(snapshot.expected(afterInserting: "x"))
  }

  func testExpectedHandlesUnicode() {
    let value = "你好，世界"
    let nsLength = (value as NSString).length
    let snapshot = ResultApplier.Snapshot(value: value, range: CFRange(location: 0, length: nsLength))
    XCTAssertEqual(snapshot.expected(afterInserting: "Hello"), "Hello")
  }
}

final class NormalizeTests: XCTestCase {
  @MainActor
  func testNormalizeTrimsWhitespacesAndNewlines() {
    XCTAssertEqual(ResultApplier.normalize("  hello\n"), "hello")
    XCTAssertEqual(ResultApplier.normalize("\n\t world  "), "world")
  }

  @MainActor
  func testNormalizeKeepsInnerContent() {
    XCTAssertEqual(ResultApplier.normalize("hello world"), "hello world")
  }

  @MainActor
  func testNormalizeEmptyString() {
    XCTAssertEqual(ResultApplier.normalize("   \n  "), "")
  }
}
