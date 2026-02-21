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
    private let systemPrompt = "Fix grammar and spelling errors, make it more concise. Return ONLY the optimized text without any explanation, notes, or formatting."

    func optimize(text: String, completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        let settings = SettingsStore.shared.load()
        let config = settings.currentConfig
        guard !config.apiKey.isEmpty else {
            completion(.failure(LLMError.missingApiKey))
            return
        }
        let effectiveBase = config.effectiveApiBase
        guard let url = URL(string: "\(effectiveBase)/chat/completions") else {
            completion(.failure(LLMError.invalidUrl))
            return
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

        // Kimi 只支持 temperature = 1
        if config.provider == .kimi {
            payload["temperature"] = 1
        } else {
            payload["temperature"] = 0.2
        }

        let requestBody: String
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            request.httpBody = bodyData
            requestBody = String(data: bodyData, encoding: .utf8) ?? ""
        } catch {
            completion(.failure(error))
            return
        }

        let startTime = Date()
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            Task { @MainActor in
                let responseTimeMs = Int(Date().timeIntervalSince(startTime) * 1000)
                if let error = error {
                    print("[LLMClient] request error: \(error)")
                    APILogStore.shared.add(
                        requestContent: text,
                        requestBody: requestBody,
                        responseContent: nil,
                        isSuccess: false,
                        errorMessage: error.localizedDescription,
                        responseTimeMs: responseTimeMs
                    )
                    completion(.failure(LLMError.requestFailed))
                    return
                }
                
                guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), let responseData = data else {
                    let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(empty)"
                    print("[LLMClient] HTTP \(statusCode): \(body)")
                    APILogStore.shared.add(
                        requestContent: text,
                        requestBody: requestBody,
                        responseContent: nil,
                        isSuccess: false,
                        errorMessage: "HTTP \(statusCode): \(body)",
                        responseTimeMs: responseTimeMs
                    )
                    completion(.failure(LLMError.invalidResponse))
                    return
                }

                let responseString = String(data: responseData, encoding: .utf8) ?? ""
                
                if let content = Self.extractText(from: responseData) {
                    APILogStore.shared.add(
                        requestContent: text,
                        requestBody: requestBody,
                        responseContent: content,
                        isSuccess: true,
                        responseTimeMs: responseTimeMs
                    )
                    completion(.success(content))
                } else {
                    APILogStore.shared.add(
                        requestContent: text,
                        requestBody: requestBody,
                        responseContent: responseString,
                        isSuccess: false,
                        errorMessage: "无法从响应中提取文本",
                        responseTimeMs: responseTimeMs
                    )
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
