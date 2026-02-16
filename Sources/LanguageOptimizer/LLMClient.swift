import Foundation

enum LLMError: Error {
    case invalidUrl
    case missingApiKey
    case requestFailed
    case invalidResponse
}

extension LLMError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "API 地址无效"
        case .missingApiKey:
            return "未配置 API Key"
        case .requestFailed:
            return "请求失败，请检查网络"
        case .invalidResponse:
            return "响应解析失败"
        }
    }
}

@MainActor
final class LLMClient {
    private let systemPrompt = "修复语法和拼写错误，尽量更简洁"

    func optimize(text: String, completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        let settings = SettingsStore.shared.load()
        guard let apiKey = SettingsStore.shared.apiKey() else {
            completion(.failure(LLMError.missingApiKey))
            return
        }
        guard let url = URL(string: "\(settings.apiBase)/chat/completions") else {
            completion(.failure(LLMError.invalidUrl))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": settings.modelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.2
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                if error != nil {
                    print("[LLMClient] request error: \(error!)")
                    completion(.failure(LLMError.requestFailed))
                    return
                }
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(empty)"
                    print("[LLMClient] HTTP \(statusCode): \(body)")
                    completion(.failure(LLMError.invalidResponse))
                    return
                }

                if let content = Self.extractText(from: data) {
                    completion(.success(content))
                } else {
                    completion(.failure(LLMError.invalidResponse))
                }
            }
        }
        task.resume()
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
