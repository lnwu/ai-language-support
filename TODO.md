# TODO

## 待办事项

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
