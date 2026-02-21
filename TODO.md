# TODO

## 待办事项

- [ ] 调用 API 时使用最新的 API 定义格式
  - **背景**: 确保 LLM 客户端发起请求时，遵循对应 Provider（如 Kimi 或 OpenAI 兼容 API）最新官方文档的规范。
  - **改动**: 检查并更新 `LLMClient` 中构建请求（Request Payload）的逻辑，如消息结构、角色定义（`system`, `user`, `assistant`）、流式响应（`stream: true`）以及其他必要参数（如 `temperature`, `max_tokens`）的格式，以确保其兼容最新的 API 标准。
