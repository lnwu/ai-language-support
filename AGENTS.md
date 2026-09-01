# Agent 指南

## 约定

- Agent 只能使用中文回复。
- 生成文档也必须使用中文。
- 生成代码时不需要注释。
- 完成任务时检查 `AGENTS.md` 和 `ARCHITECTURE.md` 是否需要更新。

## 项目

Polly 是一个 macOS 菜单栏应用，用于优化任意应用选中文本，调用 OpenAI 兼容 API 并原位替换。菜单栏使用 SwiftUI `MenuBarExtra`，设置窗口使用 SwiftUI `Settings` scene，业务逻辑通过 `AppDelegate` 驱动。

## 常用命令

- 构建：
  - `xcodebuild -project Polly.xcodeproj -scheme Polly -destination "platform=macOS,arch=arm64" build`
- 测试：
  - `xcodebuild -project Polly.xcodeproj -scheme Polly -destination "platform=macOS,arch=arm64" test`

## 关键路径

- App 入口：`Sources/Polly/AppDelegate.swift`
- SwiftUI 包装：`Sources/Polly/PollyApp.swift`
- 全局状态：`Sources/Polly/AppState.swift`
- 设置界面：`Sources/Polly/SettingsView.swift`
- 设置标签页枚举：`Sources/Polly/SettingsTab.swift`
- 设置标签页（权限/通用/测试/日志/快捷键）与视图模型：`Sources/Polly/SettingTabs/`
- 快捷键监听：`Sources/Polly/HotkeyManager.swift`
- 快捷键模型：`Sources/Polly/Hotkey.swift`
- 权限管理：`Sources/Polly/PermissionManager.swift`
- 选区获取：`Sources/Polly/SelectionProvider.swift`
- AX 树激活：`Sources/Polly/AXTreeEnabler.swift`
- 悬浮层渲染：`Sources/Polly/OverlayRenderer.swift`
- LLM 客户端：`Sources/Polly/LLMClient.swift`
- 写回处理：`Sources/Polly/ResultApplier.swift`
- 配置存储：`Sources/Polly/SettingsStore.swift`、`Sources/Polly/KeychainStore.swift`
- 日志存储：`Sources/Polly/AppLogStore.swift`、`Sources/Polly/APILogStore.swift`
- 国际化管理：`Sources/Polly/LocalizationManager.swift`
- 本地化资源：`Sources/Polly/Resources/en.lproj/`、`Sources/Polly/Resources/zh-Hans.lproj/`
- 单元测试（XCTest，`@testable import Polly`）：`Tests/PollyTests/`
