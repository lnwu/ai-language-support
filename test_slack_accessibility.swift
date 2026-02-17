import ApplicationServices
import AppKit

// 测试从 Slack 获取选中文本
func testSlackSelection() {
    guard AXIsProcessTrusted() else {
        print("错误：未获得辅助功能权限")
        return
    }
    
    // 获取当前前台应用
    guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
        print("错误：无法获取前台应用")
        return
    }
    
    print("前台应用: \(frontmostApp.localizedName ?? "未知")")
    print("Bundle ID: \(frontmostApp.bundleIdentifier ?? "未知")")
    
    // 获取系统范围的元素
    let systemElement = AXUIElementCreateSystemWide()
    
    // 获取聚焦元素
    var focused: CFTypeRef?
    let focusedResult = AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focused)
    
    if focusedResult != .success {
        print("错误：无法获取聚焦元素 (状态码: \(focusedResult.rawValue))")
        return
    }
    
    guard let focusedElement = focused else {
        print("错误：聚焦元素为空")
        return
    }
    
    print("✓ 成功获取聚焦元素")
    
    // 尝试获取选中文本
    var selectedTextValue: CFTypeRef?
    let selectedTextResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextAttribute as CFString, &selectedTextValue)
    
    if selectedTextResult == .success, let selectedText = selectedTextValue as? String {
        print("✓ 选中文本: '\(selectedText)'")
    } else {
        print("✗ 无法获取选中文本 (状态码: \(selectedTextResult.rawValue))")
    }
    
    // 尝试获取选区范围
    var selectedRangeValue: CFTypeRef?
    let selectedRangeResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXSelectedTextRangeAttribute as CFString, &selectedRangeValue)
    
    if selectedRangeResult == .success {
        print("✓ 成功获取选区范围")
    } else {
        print("✗ 无法获取选区范围 (状态码: \(selectedRangeResult.rawValue))")
    }
    
    // 尝试获取元素的角色
    var roleValue: CFTypeRef?
    let roleResult = AXUIElementCopyAttributeValue(focusedElement as! AXUIElement, kAXRoleAttribute as CFString, &roleValue)
    
    if roleResult == .success, let role = roleValue as? String {
        print("元素角色: \(role)")
    }
    
    // 尝试获取元素的所有属性
    var attributeNames: CFArray?
    let namesResult = AXUIElementCopyAttributeNames(focusedElement as! AXUIElement, &attributeNames)
    
    if namesResult == .success, let names = attributeNames as? [String] {
        print("\n可用属性 (\(names.count) 个):")
        for name in names.prefix(10) {
            print("  - \(name)")
        }
        if names.count > 10 {
            print("  ... 还有 \(names.count - 10) 个")
        }
    }
}

testSlackSelection()
