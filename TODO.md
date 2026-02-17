# TODO

## 待办事项

### 1. 快捷键默认改为 ⇧⌘R

- **文件**: `Sources/LanguageOptimizer/Hotkey.swift:19-20`
- **改动**: `default()` 方法中，`keyCode` 从 `kVK_ANSI_E` 改为 `kVK_ANSI_R`，`modifiers` 从 `[.command]` 改为 `[.command, .shift]`，`display` 从 `"⌘E"` 改为 `"⇧⌘R"`

### 2. 设置窗口支持 Cmd+Tab 切换

- **问题**: 当前应用为纯菜单栏应用（accessory），不参与 Cmd+Tab 切换，设置窗口打开后容易被其他窗口遮挡且无法通过 Cmd+Tab 找回
- **方案**: 打开设置窗口时临时将 `NSApp.setActivationPolicy(.regular)` 使应用出现在 Dock 和 Cmd+Tab 中；关闭设置窗口后切回 `.accessory`
- **文件**: `Sources/LanguageOptimizer/LanguageOptimizerApp.swift`
- **改动**:
  - 打开设置时调用 `NSApp.setActivationPolicy(.regular)`
  - 监听设置窗口关闭事件（通过 `NSWindow.willCloseNotification`），关闭后调用 `NSApp.setActivationPolicy(.accessory)`

### 3. 权限说明加上 Keychain 说明

- **文件**: `Sources/LanguageOptimizer/SettingsView.swift` 的 `permissionsTab`
- **改动**: 在辅助功能权限说明区域下方，增加 Keychain 权限说明段落
- **内容**: 说明应用使用 macOS Keychain 安全存储 API Key，首次保存时系统可能弹出 Keychain 访问确认弹窗，这是正常行为，请允许访问以确保 API Key 安全存储

### 4. API 设置默认不给任何值

- **文件**: `Sources/LanguageOptimizer/SettingsStore.swift:27`
- **改动**: `load()` 方法中 `apiBase` 默认值从 `"https://api.openai.com/v1"` 改为 `""`
- **文件**: `Sources/LanguageOptimizer/SettingsView.swift:6`
- **改动**: `@State apiBase` 初始值从 `"https://api.openai.com/v1"` 改为 `""`

### 5. 回填策略：默认 AX 写入，白名单强制粘贴

- **问题**: 当前 `AppDelegate.handleHotkey()` 无条件调用 `forcePaste()`，所有应用都走模拟粘贴（Cmd+V）路径，会干扰用户剪贴板
- **方案**: 默认使用 `ResultApplier.apply()`（优先 Accessibility API 直接写入，失败再回退粘贴）；仅白名单应用使用 `forcePaste()`
- **白名单**:
  - Slack: `com.tinyspeck.slackmacgap`
  - Apple Notes: `com.apple.Notes`
- **文件**: `Sources/LanguageOptimizer/AppDelegate.swift:48`
- **改动**: 将 `resultApplier.forcePaste(text:targetPid:)` 替换为根据 `selection.appBundleId` 判断调用逻辑：
  ```swift
  let forcePasteBundleIds = ["com.tinyspeck.slackmacgap", "com.apple.Notes"]
  let applyResult: Result<Void, Error>
  if forcePasteBundleIds.contains(selection.appBundleId) {
      applyResult = self?.resultApplier.forcePaste(text: optimized, targetPid: selection.appPid)
  } else {
      applyResult = self?.resultApplier.apply(text: optimized, targetPid: selection.appPid)
  }
  ```

### 6. 没有选中文字时按下快捷键不做任何操作

- **文件**: `Sources/LanguageOptimizer/AppDelegate.swift` 的 `handleHotkey()` 中 `catch` 块
- **改动**: 对 `SelectionError.noSelection` 和 `SelectionError.noFocusedElement` 静默返回（仅记录 debug 日志），不显示错误悬浮层。只有 `.notTrusted` 打开设置页，其他未知错误才显示错误指示器
- **当前行为**: 获取选区失败时，除 `.notTrusted` 外一律在鼠标位置显示错误悬浮层
- **目标行为**:
  ```swift
  } catch {
      if let selectionError = error as? SelectionError {
          switch selectionError {
          case .notTrusted:
              AppState.shared.requestOpenSettings(tab: .permissions)
          case .noSelection, .noFocusedElement:
              // 静默忽略，不做任何操作
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
  ```
