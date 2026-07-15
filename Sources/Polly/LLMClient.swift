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
            return "error.llm.invalid_url".localized
        case .missingApiKey:
            return "error.llm.missing_api_key".localized
        case .requestFailed(let statusCode, let body):
            return "error.llm.request_failed".localized(statusCode, body)
        case .invalidResponse:
            return "error.llm.invalid_response".localized
        }
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
}

private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

private struct ChatResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        let content: String
    }
}

struct ModelsResponse: Decodable {
    let data: [Model]

    struct Model: Decodable {
        let id: String
    }
}

@MainActor
final class LLMClient {
    private let systemPrompt = "Fix grammar and spelling errors, make it more concise. Return ONLY the optimized text without any explanation, notes, or formatting."

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()

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

        let chatRequest = ChatRequest(
            model: config.modelName,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: text)
            ],
            temperature: 0.2
        )

        let bodyData = try encoder.encode(chatRequest)
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

        guard let chatResponse = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let first = chatResponse.choices.first else {
            let responseString = String(data: data, encoding: .utf8) ?? ""
            APILogStore.shared.add(
                requestContent: text,
                requestBody: requestBody,
                responseContent: responseString,
                isSuccess: false,
                errorMessage: "error.llm.no_content".localized,
                responseTimeMs: responseTimeMs
            )
            throw LLMError.invalidResponse
        }

        let content = first.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            APILogStore.shared.add(
                requestContent: text,
                requestBody: requestBody,
                responseContent: "",
                isSuccess: false,
                errorMessage: "error.llm.no_content".localized,
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
}
