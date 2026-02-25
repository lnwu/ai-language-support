# Agent 指南

## 约定

- Agent 只能使用中文回复。
- 生成文档也必须使用中文。
- 生成代码时不需要注释。
- 完成任务时检查 `AGENTS.md` 是否需要更新。

## 项目

Polly 是一个 macOS 菜单栏应用，用于优化任意应用选中文本，调用 OpenAI 兼容 API 并原位替换。菜单栏使用 SwiftUI `MenuBarExtra`，设置窗口使用 SwiftUI `Settings` scene，业务逻辑通过 `AppDelegate` 驱动。

## 快速开始

- 用 Xcode 打开 `Polly.xcodeproj`
- 从 Xcode 运行应用
- 按提示授予辅助功能权限
- 在设置中配置 API Base / Model / API Key

## 常用命令

- 构建：
  - `xcodebuild -project Polly.xcodeproj -scheme Polly -destination "platform=macOS,arch=arm64" build`

## 关键路径

- App 入口：`Sources/Polly/AppDelegate.swift`
- SwiftUI 包装：`Sources/Polly/PollyApp.swift`
- 设置界面：`Sources/Polly/SettingsView.swift`
- 快捷键监听：`Sources/Polly/HotkeyManager.swift`
- 选区获取：`Sources/Polly/SelectionProvider.swift`
- 悬浮层渲染：`Sources/Polly/OverlayRenderer.swift`
- LLM 客户端：`Sources/Polly/LLMClient.swift`
- 写回处理：`Sources/Polly/ResultApplier.swift`
- 配置存储：`Sources/Polly/SettingsStore.swift`、`Sources/Polly/KeychainStore.swift`
- 日志存储：`Sources/Polly/AppLogStore.swift`、`Sources/Polly/APILogStore.swift`

## 说明

- 使用 macOS Accessibility API 获取选区与写回。
- `LLMClient` 使用 async/await 调用 `/chat/completions` API。
- 日志仅存在于内存中，不做持久化，应用重启后自动清空。
- `ResultApplier` 内部维护强制粘贴的应用列表，调用方传入 `appBundleId` 即可，无需关心写回策略。
