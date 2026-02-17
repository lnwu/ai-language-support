# Agent 指南

## 约定
- Agent 只能使用中文回复。
- 生成代码时不需要注释。
- 生成文档也必须使用中文。
- 完成任务时检查 `AGENTS.md` 是否需要更新。

## 项目
LanguageOptimizer 是一个 macOS 菜单栏应用，用于优化任意应用选中文本，调用 OpenAI 兼容 API 并原位替换。菜单栏使用 SwiftUI `MenuBarExtra`，设置窗口使用 SwiftUI `Settings` scene，业务逻辑通过 `AppDelegate` 驱动。

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
- 快捷键监听：`Sources/LanguageOptimizer/HotkeyManager.swift`
- 选区获取：`Sources/LanguageOptimizer/SelectionProvider.swift`
- 悬浮层渲染：`Sources/LanguageOptimizer/OverlayRenderer.swift`
- LLM 客户端：`Sources/LanguageOptimizer/LLMClient.swift`
- 写回处理：`Sources/LanguageOptimizer/ResultApplier.swift`
- 配置存储：`Sources/LanguageOptimizer/SettingsStore.swift`、`Sources/LanguageOptimizer/KeychainStore.swift`

## 说明
- 使用 macOS Accessibility API 获取选区与写回。
- `LLMClient` 默认使用 Responses API。
- **不要运行 `xcodegen generate`**：xcodegen 2.44.1 生成 objectVersion=77 格式缺少 `PBXResourcesBuildPhase`，会导致 `Assets.xcassets` 不被打包。当前 pbxproj 已手动修补，直接编辑 `.xcodeproj/project.pbxproj` 即可。
