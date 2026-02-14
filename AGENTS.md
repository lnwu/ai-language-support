# Agent 指南

## 约定
- Agent 只能使用中文回复。
- 生成代码时不需要注释。
- 生成文档也必须使用中文。
- 完成任务时检查 `AGENTS.md` 是否需要更新。

## 项目
LanguageOptimizer 是一个 macOS 菜单栏应用，用于优化 Slack 选中文本，调用 OpenAI 兼容 API 并原位替换。系统集成使用 AppKit，设置界面使用 SwiftUI。

## 快速开始
- 用 Xcode 打开 `LanguageOptimizer.xcodeproj`
- 从 Xcode 运行应用
- 按提示授予辅助功能权限
- 在设置中配置 API Base / Model / API Key

## 常用命令
- 构建：
  - `xcodebuild -project LanguageOptimizer.xcodeproj -scheme LanguageOptimizer -destination "platform=macOS,arch=arm64" build`

## 关键路径
- App 入口：`Sources/LanguageOptimizer/AppDelegate.swift`
- SwiftUI 包装：`Sources/LanguageOptimizer/LanguageOptimizerApp.swift`
- 设置界面：`Sources/LanguageOptimizer/SettingsView.swift`
- 快捷键监听：`Sources/LanguageOptimizer/HotkeyListener.swift`
- 选区获取：`Sources/LanguageOptimizer/SelectionProvider.swift`
- 悬浮层渲染：`Sources/LanguageOptimizer/OverlayRenderer.swift`
- LLM 客户端：`Sources/LanguageOptimizer/LLMClient.swift`
- 写回处理：`Sources/LanguageOptimizer/ResultApplier.swift`
- 配置存储：`Sources/LanguageOptimizer/SettingsStore.swift`、`Sources/LanguageOptimizer/KeychainStore.swift`

## 说明
- 仅在 Slack 前台时触发（bundle id：`com.tinyspeck.slackmacgap`）。
- 使用 macOS Accessibility API 获取选区与写回。
- `LLMClient` 默认使用 Responses API。
