import Foundation

struct RemoteAIServiceConfiguration {
    let endpoint: URL?
    let bearerToken: String?
    let model: String?
}

enum RemoteAIServiceError: LocalizedError {
    case notConfigured
    case requestFailed(String)
    case httpStatus(Int, String?)
    case badServerResponse(String?)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI 远程服务尚未配置。"
        case let .requestFailed(message):
            return "AI 请求失败：\(message)"
        case let .httpStatus(statusCode, body):
            if let body, !body.isEmpty {
                return "AI 服务返回异常（HTTP \(statusCode)）：\(body)"
            }
            return "AI 服务返回异常（HTTP \(statusCode)）。"
        case let .badServerResponse(body):
            if let body, !body.isEmpty {
                return "AI 服务返回了无法识别的结果：\(body)"
            }
            return "AI 服务返回了无法识别的结果。"
        }
    }
}

final class RemoteAIStudyService: AIStudyServiceProtocol {
    private enum EndpointProtocol {
        case custom
        case openAICompatible
    }

    private struct RequestBody: Encodable {
        let style: String
        let question: Question
    }

    private struct ResponseBody: Decodable {
        let title: String
        let summary: String
        let highlights: [String]
        let nextAction: String
        let source: String?
    }

    private struct OpenAIChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
    }

    private struct OpenAIChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }

            let message: Message
        }

        let choices: [Choice]
    }

    private let configurationProvider: () -> RemoteAIServiceConfiguration
    private let session: URLSession

    init(
        configurationProvider: @escaping () -> RemoteAIServiceConfiguration,
        session: URLSession = .shared
    ) {
        self.configurationProvider = configurationProvider
        self.session = session
    }

    func generateInsight(for question: Question, style: AIInsightStyle) async throws -> AIStudyInsight {
        let configuration = configurationProvider()

        guard let endpoint = configuration.endpoint else {
            throw RemoteAIServiceError.notConfigured
        }

        switch endpointProtocol(for: configuration, endpoint: endpoint) {
        case .custom:
            return try await generateViaCustomEndpoint(
                endpoint: endpoint,
                token: configuration.bearerToken,
                question: question,
                style: style
            )
        case .openAICompatible:
            return try await generateViaOpenAICompatibleEndpoint(
                endpoint: endpoint,
                token: configuration.bearerToken,
                model: configuration.model,
                question: question,
                style: style
            )
        }
    }

    private func generateViaCustomEndpoint(
        endpoint: URL,
        token: String?,
        question: Question,
        style: AIInsightStyle
    ) async throws -> AIStudyInsight {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = sanitized(token) {
            request.setValue(authorizationHeaderValue(for: token), forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(RequestBody(style: style.rawValue, question: question))

        let (data, response) = try await performRequest(request)
        try validateHTTPResponse(response, data: data)

        let decoded: ResponseBody
        do {
            decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        } catch {
            throw RemoteAIServiceError.badServerResponse(bodySnippet(from: data))
        }

        return AIStudyInsight(
            title: decoded.title,
            summary: decoded.summary,
            highlights: decoded.highlights,
            nextAction: decoded.nextAction,
            source: decoded.source ?? "远程 AI"
        )
    }

    private func generateViaOpenAICompatibleEndpoint(
        endpoint: URL,
        token: String?,
        model: String?,
        question: Question,
        style: AIInsightStyle
    ) async throws -> AIStudyInsight {
        let resolvedEndpoint = resolvedOpenAICompatibleEndpoint(from: endpoint)
        let resolvedModel = try resolvedModel(for: model, endpoint: endpoint)

        var request = URLRequest(url: resolvedEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = sanitized(token) {
            request.setValue(authorizationHeaderValue(for: token), forHTTPHeaderField: "Authorization")
        }

        let requestBody = OpenAIChatRequest(
            model: resolvedModel,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt(for: question, style: style))
            ],
            temperature: 0.3
        )
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await performRequest(request)
        try validateHTTPResponse(response, data: data)

        let decodedResponse: OpenAIChatResponse
        do {
            decodedResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
        } catch {
            throw RemoteAIServiceError.badServerResponse(bodySnippet(from: data))
        }

        guard let content = sanitized(decodedResponse.choices.first?.message.content) else {
            throw RemoteAIServiceError.badServerResponse(bodySnippet(from: data))
        }

        return try decodeInsight(
            from: content,
            fallbackSource: sourceLabel(for: endpoint, model: resolvedModel)
        )
    }

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw RemoteAIServiceError.requestFailed(error.localizedDescription)
        }
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw RemoteAIServiceError.httpStatus(statusCode, bodySnippet(from: data))
        }
    }

    private func decodeInsight(from content: String, fallbackSource: String) throws -> AIStudyInsight {
        let normalized = normalizedJSONPayload(from: content)

        guard let data = normalized.data(using: .utf8) else {
            throw RemoteAIServiceError.badServerResponse(normalized)
        }

        let decoded: ResponseBody
        do {
            decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        } catch {
            throw RemoteAIServiceError.badServerResponse(normalized)
        }

        return AIStudyInsight(
            title: decoded.title,
            summary: decoded.summary,
            highlights: decoded.highlights,
            nextAction: decoded.nextAction,
            source: decoded.source ?? fallbackSource
        )
    }

    private var systemPrompt: String {
        """
        你是软考高级系统架构师刷题助手。请只返回一个 JSON 对象，不要输出 markdown，不要输出额外说明。
        JSON 必须包含字段：title、summary、highlights、nextAction、source。
        要求：
        1. 使用简体中文。
        2. title 控制在 20 字以内。
        3. summary 控制在 120 字以内。
        4. highlights 必须是 3 条字符串数组。
        5. nextAction 必须是 1 句可执行建议。
        6. source 写你当前使用的模型或服务名称。
        """
    }

    private func userPrompt(for question: Question, style: AIInsightStyle) -> String {
        let optionsText: String
        if question.options.isEmpty {
            optionsText = "无"
        } else {
            optionsText = question.options
                .map { "\($0.label). \($0.content)" }
                .joined(separator: "\n")
        }

        let styleInstruction: String
        switch style {
        case .explanation:
            styleInstruction = "输出重点放在考点讲解、正确答案依据和易错点提醒。"
        case .similarQuestion:
            styleInstruction = "输出重点放在生成一题同考点变体题，并给出迁移思路与训练建议。"
        case .essayOutline:
            styleInstruction = "输出重点放在论文/案例题提纲，建议按背景、问题、方案、收益、反思组织。"
        }

        return """
        当前任务：\(style.title)
        \(styleInstruction)

        题目信息：
        - 题型：\(question.type.title)
        - 来源：\(question.sourceText)
        - 分类：\(question.category)
        - 知识点：\(question.knowledgePoints.joined(separator: "、"))
        - 题干：\(question.stem)
        - 选项：
        \(optionsText)
        - 参考答案：\(question.answerSummary)
        - 参考解析：\(question.analysis)
        """
    }

    private func endpointProtocol(for configuration: RemoteAIServiceConfiguration, endpoint: URL) -> EndpointProtocol {
        if sanitized(configuration.model) != nil {
            return .openAICompatible
        }

        let host = endpoint.host()?.lowercased() ?? ""
        if host.contains("openai.com") || host.contains("deepseek.com") {
            return .openAICompatible
        }

        if endpoint.path.lowercased().contains("/chat/completions") {
            return .openAICompatible
        }

        return .custom
    }

    private func resolvedOpenAICompatibleEndpoint(from endpoint: URL) -> URL {
        let path = endpoint.path.lowercased()
        if path.contains("/chat/completions") {
            return endpoint
        }

        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return endpoint
        }

        if components.path.isEmpty || components.path == "/" {
            components.path = "/v1/chat/completions"
        } else if components.path.hasSuffix("/v1") {
            components.path += "/chat/completions"
        } else if components.path.hasSuffix("/v1/") {
            components.path += "chat/completions"
        } else {
            components.path += components.path.hasSuffix("/") ? "chat/completions" : "/chat/completions"
        }

        return components.url ?? endpoint
    }

    private func resolvedModel(for model: String?, endpoint: URL) throws -> String {
        if let model = sanitized(model) {
            return model
        }

        let host = endpoint.host()?.lowercased() ?? ""
        if host.contains("openai.com") {
            return "gpt-4.1-mini"
        }
        if host.contains("deepseek.com") {
            return "deepseek-chat"
        }

        throw RemoteAIServiceError.requestFailed("OpenAI 兼容接口需要填写模型名称。")
    }

    private func sourceLabel(for endpoint: URL, model: String) -> String {
        let host = endpoint.host()?.lowercased() ?? ""
        if host.contains("openai.com") {
            return "OpenAI · \(model)"
        }
        if host.contains("deepseek.com") {
            return "DeepSeek · \(model)"
        }
        return "远程 AI · \(model)"
    }

    private func normalizedJSONPayload(from content: String) -> String {
        let stripped = stripCodeFence(from: content)
        if let object = extractJSONObject(from: stripped) {
            return object
        }
        return stripped
    }

    private func stripCodeFence(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```"), trimmed.hasSuffix("```") else {
            return trimmed
        }

        var lines = trimmed.components(separatedBy: .newlines)
        if !lines.isEmpty {
            lines.removeFirst()
        }
        if !lines.isEmpty {
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else {
            return nil
        }

        var depth = 0
        var inString = false
        var isEscaping = false

        for index in text[start...].indices {
            let character = text[index]

            if inString {
                if isEscaping {
                    isEscaping = false
                } else if character == "\\" {
                    isEscaping = true
                } else if character == "\"" {
                    inString = false
                }
                continue
            }

            if character == "\"" {
                inString = true
                continue
            }

            if character == "{" {
                depth += 1
            } else if character == "}" {
                depth -= 1
                if depth == 0 {
                    return String(text[start...index])
                }
            }
        }

        return nil
    }

    private func authorizationHeaderValue(for token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains(" ") {
            return trimmed
        }
        return "Bearer \(trimmed)"
    }

    private func bodySnippet(from data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            return nil
        }

        if text.count <= 160 {
            return text
        }

        return String(text.prefix(160)) + "…"
    }

    private func sanitized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
