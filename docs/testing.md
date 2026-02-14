# 测试指南（LanguageOptimizer）

## 运行前准备
- macOS 26
- Slack 桌面客户端（bundle id: `com.tinyspeck.slackmacgap`）
- 已在设置页填写 API Base / Model / API Key

## 首次启动检查
1. 运行应用（Xcode Run 或双击 `LanguageOptimizer.app`）。
2. 系统会提示开启辅助功能权限（Accessibility）。
3. 打开 系统设置 → 隐私与安全性 → 辅助功能，勾选 LanguageOptimizer。

## 基础功能测试
1. 打开 Slack，进入任意输入框。
2. 输入一段包含拼写或语法问题的文本。
3. 选中文本，按 `CMD + E`。
4. 预期结果：
   - 选区右上角出现三点跳动提示，3 秒内自动消失或请求完成即消失。
   - 文本被优化替换。

## 选区与定位测试
- 单行选区：测试短句替换。
- 多行选区：测试跨行替换与位置提示。
- 不同长度文本：短句/长段落均能替换。

## 错误与异常场景
- 未授权 Accessibility：
  - 触发 `CMD + E` 预期提示“未获得辅助功能权限”。
- 未选中文本：
  - 触发 `CMD + E` 预期提示“未检测到选中文本”。
- API Key 为空：
  - 预期提示“未配置 API Key”。
- API Base 不可达：
  - 预期提示“请求失败，请检查网络”。
- 响应解析失败：
  - 预期提示“响应解析失败”。

## 写回失败兜底验证
1. 在 Slack 里选中内容后，手动切换到其它应用窗口。
2. 触发 `CMD + E`。
3. 预期结果：提示“替换失败，内容已在剪贴板”。
4. 手动在 Slack 粘贴，确认内容为优化结果。

## 设置持久化验证
1. 打开 Settings，修改 API Base / Model / 目标提示。
2. 点击 Save，退出应用并重新打开。
3. 确认设置值仍然存在。
4. API Key 需能从 Keychain 读取。

## 运行与构建
- 构建：`xcodebuild -project LanguageOptimizer.xcodeproj -scheme LanguageOptimizer -destination "platform=macOS,arch=arm64" build`
- 运行：Xcode 直接 Run，或从 `DerivedData` 中启动 `.app`
