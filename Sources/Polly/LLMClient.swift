import Foundation

enum LLMError: Error {
    case invalidUrl
    case missingApiKey
    case requestFailed(statusCode: Int, body: String)
    case invalidResponse
}

extension LLMError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "API 地址无效"
        case .missingApiKey:
            return "未配置 API Key"
        case .requestFailed(let statusCode, let body):
            return "请求失败 (HTTP \(statusCode)): \(body)"
        case .invalidResponse:
            return "响应解析失败"
        }
    }
}

@MainActor
final class LLMClient {
    private let systemPrompt = "Fix grammar and spelling errors, make it more concise. Return ONLY the optimized text without any explanation, notes, or formatting."

    func optimize(text: String) async throws -> String {
        let settings = SettingsStore.shared.load()
        let config = settings.currentConfig
        guard !config.apiKey.isEmpty else {
            throw LLMError.missingApiKey
        }
        let effectiveBase = config.effectiveApiBase
        guard let url = URL(string: "\(effectiveBase)/chat/completions") else {
            throw LLMError.invalidUrl
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")

        var payload: [String: Any] = [
            "model": config.modelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ]
        ]

        if config.provider == .kimi {
            payload["temperature"] = 1
        } else {
            payload["temperature"] = 0.2
        }

        let bodyData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
        request.httpBody = bodyData
        let requestBody = String(data: bodyData, encoding: .utf8) ?? ""

        let startTime = Date()
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            let responseTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
            APILogStore.shared.add(
                requestContent: text,
                requestBody: requestBody,
                responseContent: nil,
                isSuccess: false,
                errorMessage: error.localizedDescription,
                responseTimeMs: responseTimeMs
            )
            throw LLMError.requestFailed(statusCode: -1, body: error.localizedDescription)
        }

        let responseTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? "(empty)"
            APILogStore.shared.add(
                requestContent: text,
                requestBody: requestBody,
                responseContent: nil,
                isSuccess: false,
                errorMessage: "HTTP \(statusCode): \(body)",
                responseTimeMs: responseTimeMs
            )
            throw LLMError.requestFailed(statusCode: statusCode, body: body)
        }

        guard let content = Self.extractText(from: data) else {
            let responseString = String(data: data, encoding: .utf8) ?? ""
            APILogStore.shared.add(
                requestContent: text,
                requestBody: requestBody,
                responseContent: responseString,
                isSuccess: false,
                errorMessage: "无法从响应中提取文本",
                responseTimeMs: responseTimeMs
            )
            throw LLMError.invalidResponse
        }

        APILogStore.shared.add(
            requestContent: text,
            requestBody: requestBody,
            responseContent: content,
            isSuccess: true,
            responseTimeMs: responseTimeMs
        )
        return content
    }

    private static func extractText(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data, options: []),
              let dict = object as? [String: Any],
              let choices = dict["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
