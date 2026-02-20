# TODO

## 待办事项

- [ ] 回填策略：默认 AX 写入，白名单强制粘贴
  - **问题**: 当前 `AppDelegate.handleHotkey()` 无条件调用 `forcePaste()`，所有应用都走模拟粘贴（Cmd+V）路径，会干扰用户剪贴板
  - **方案**: 默认使用 `ResultApplier.apply()`（优先 Accessibility API 直接写入，失败再回退粘贴）；仅白名单应用使用 `forcePaste()`
  - **白名单**:
    - Slack: `com.tinyspeck.slackmacgap`
    - Apple Notes: `com.apple.Notes`
  - **文件**: `Sources/Polly/AppDelegate.swift:48`
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

- [ ] 没有选中文字时按下快捷键不做任何操作
  - **文件**: `Sources/Polly/AppDelegate.swift` 的 `handleHotkey()` 中 `catch` 块
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

- [ ] API 设置支持选择 Provider
  - **背景**: 提升用户体验，针对预置的 Provider 隐藏复杂的 Endpoint 和模型配置，只需填写 API Key 即可。
  - **方案**:
    - 在设置中增加 Provider 选项：`Kimi (Moonshot)` 和 `OpenAI 兼容` (自定义)。
    - **Kimi (Moonshot)**: 选中时，内置 API Base (如 `https://api.moonshot.cn/v1`)，用户只需填写 API Key 并选择或输入模型（如 `moonshot-v1-8k` 等），**隐藏 API Base 输入框**。
    - **OpenAI 兼容**: 选中时，行为与当前一致，**显示 API Base 输入框**，用户需完整填写 API Base、Model 和 API Key。
  - **UI 变更**: `SettingsView` 的 API 设置区域顶部增加一个 `Picker` 用于选择 Provider。根据选择动态显示或隐藏 `API Base` 输入框。
  - **存储变更**: `SettingsStore` 中增加 `apiProvider` 字段以持久化用户的选择。

- [ ] 调用 API 时使用最新的 API 定义格式
  - **背景**: 确保 LLM 客户端发起请求时，遵循对应 Provider（如 Kimi 或 OpenAI 兼容 API）最新官方文档的规范。
  - **改动**: 检查并更新 `LLMClient` 中构建请求（Request Payload）的逻辑，如消息结构、角色定义（`system`, `user`, `assistant`）、流式响应（`stream: true`）以及其他必要参数（如 `temperature`, `max_tokens`）的格式，以确保其兼容最新的 API 标准。
