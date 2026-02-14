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
        guard let url = URL(string: "\(settings.apiBase)/responses") else {
            completion(.failure(LLMError.invalidUrl))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "model": settings.modelName,
            "input": [
                [
                    "role": "system",
                    "content": [
                        ["type": "input_text", "text": systemPrompt]
                    ]
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "input_text", "text": text]
                    ]
                ]
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
                    completion(.failure(LLMError.requestFailed))
                    return
                }
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let data else {
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
              let dict = object as? [String: Any] else {
            return nil
        }

        if let output = dict["output"] as? [[String: Any]] {
            for item in output {
                if let type = item["type"] as? String, type == "message",
                   let content = item["content"] as? [[String: Any]] {
                    for part in content {
                        if let partType = part["type"] as? String, partType == "output_text",
                           let text = part["text"] as? String {
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty { return trimmed }
                        }
                    }
                }
            }
        }

        if let choices = dict["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return nil
    }
}
