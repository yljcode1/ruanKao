import Foundation

struct RemoteAIServiceConfiguration {
    let endpoint: URL?
    let bearerToken: String?
    let model: String?
    let protocolPreference: AIServiceProtocolPreference
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
        case responses
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

    private struct ResponsesAPIRequest: Encodable {
        struct Reasoning: Encodable {
            let effort: String
        }

        struct TextConfiguration: Encodable {
            struct Format: Encodable {
                let type: String
                let name: String
                let schema: InsightSchema
                let strict: Bool
            }

            let format: Format
        }

        let model: String
        let instructions: String?
        let input: String
        let store: Bool?
        let reasoning: Reasoning?
        let text: TextConfiguration?
    }

    private struct ResponsesAPIMessageRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: [Content]
        }

        struct Content: Encodable {
            let type = "input_text"
            let text: String
        }

        let model: String
        let input: [Message]
        let store: Bool?
    }

    private struct InsightSchema: Encodable {
        let type = "object"
        let properties = Properties()
        let required = ["title", "summary", "highlights", "nextAction", "source"]
        let additionalProperties = false

        struct Properties: Encodable {
            let title = StringProperty(description: "20 字以内的中文标题")
            let summary = StringProperty(description: "120 字以内的中文总结")
            let highlights = ArrayProperty()
            let nextAction = StringProperty(description: "1 句可执行建议")
            let source = StringProperty(description: "当前模型或服务名称")
        }

        struct StringProperty: Encodable {
            let type = "string"
            let description: String
        }

        struct ArrayProperty: Encodable {
            let type = "array"
            let items = Item()
            let minItems = 3
            let maxItems = 3

            struct Item: Encodable {
                let type = "string"
            }
        }
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
        try await generateInsight(
            for: question,
            style: style,
            configuration: configurationProvider()
        )
    }

    func testConnection() async throws -> String {
        let insight = try await generateInsight(
            for: Self.testQuestion,
            style: .explanation,
            configuration: configurationProvider()
        )
        return insight.source
    }

    private func generateInsight(
        for question: Question,
        style: AIInsightStyle,
        configuration: RemoteAIServiceConfiguration
    ) async throws -> AIStudyInsight {
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
        case .responses:
            return try await generateViaResponsesEndpoint(
                endpoint: endpoint,
                token: configuration.bearerToken,
                model: configuration.model,
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

    private static var testQuestion: Question {
        Question(
            id: -1,
            year: 2026,
            stage: "测试连接",
            type: .singleChoice,
            category: "AI 联通性",
            knowledgePoints: ["接口配置", "鉴权", "连通性"],
            stem: "这是一个用于检测 AI 接口是否可用的测试题。",
            options: [
                .init(label: "A", content: "连通"),
                .init(label: "B", content: "未连通")
            ],
            correctAnswers: ["A"],
            analysis: "如果能返回结构化讲解，说明当前 AI 接口、模型和令牌均可用。",
            score: 1,
            estimatedMinutes: 1
        )
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
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

    private func generateViaResponsesEndpoint(
        endpoint: URL,
        token: String?,
        model: String?,
        question: Question,
        style: AIInsightStyle
    ) async throws -> AIStudyInsight {
        let resolvedEndpoint = resolvedResponsesEndpoint(from: endpoint)
        let resolvedModel = try resolvedModel(for: model, endpoint: endpoint)
        let fallbackSource = sourceLabel(for: endpoint, model: resolvedModel)

        let requestVariants = try responsesRequestVariants(
            model: resolvedModel,
            question: question,
            style: style
        )

        var lastError: Error?
        for requestBody in requestVariants {
            do {
                return try await executeResponsesRequest(
                    endpoint: resolvedEndpoint,
                    token: token,
                    requestBodyData: requestBody,
                    fallbackSource: fallbackSource
                )
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }

        throw RemoteAIServiceError.requestFailed("Responses API 请求失败。")
    }

    private func executeResponsesRequest(
        endpoint: URL,
        token: String?,
        requestBodyData: Data,
        fallbackSource: String
    ) async throws -> AIStudyInsight {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyOpenAICompatibleAuthHeaders(to: &request, token: token)
        request.httpBody = requestBodyData

        let (data, response) = try await performRequest(request)
        try validateHTTPResponse(response, data: data)

        if let insight = try decodeInsightIfPresent(in: data, fallbackSource: fallbackSource) {
            return insight
        }

        guard let content = extractedResponsesText(from: data) else {
            throw RemoteAIServiceError.badServerResponse(bodySnippet(from: data))
        }

        do {
            return try decodeInsight(from: content, fallbackSource: fallbackSource)
        } catch {
            return fallbackInsight(from: content, fallbackSource: fallbackSource)
        }
    }

    private func responsesRequestVariants(
        model: String,
        question: Question,
        style: AIInsightStyle
    ) throws -> [Data] {
        let standardInput = userPrompt(for: question, style: style)
        let combinedInput = combinedResponsesPrompt(for: question, style: style)
        let encoder = JSONEncoder()

        return try [
            encoder.encode(ResponsesAPIRequest(
                model: model,
                instructions: systemPrompt,
                input: standardInput,
                store: false,
                reasoning: defaultResponsesReasoning(for: model).map(ResponsesAPIRequest.Reasoning.init),
                text: ResponsesAPIRequest.TextConfiguration(
                    format: .init(
                        type: "json_schema",
                        name: "ai_study_insight",
                        schema: InsightSchema(),
                        strict: true
                    )
                )
            )),
            encoder.encode(ResponsesAPIRequest(
                model: model,
                instructions: systemPrompt,
                input: standardInput,
                store: nil,
                reasoning: nil,
                text: nil
            )),
            encoder.encode(ResponsesAPIRequest(
                model: model,
                instructions: nil,
                input: combinedInput,
                store: nil,
                reasoning: nil,
                text: nil
            )),
            encoder.encode(ResponsesAPIMessageRequest(
                model: model,
                input: [
                    .init(role: "system", content: [.init(text: systemPrompt)]),
                    .init(role: "user", content: [.init(text: standardInput)])
                ],
                store: nil
            )),
            encoder.encode(ResponsesAPIMessageRequest(
                model: model,
                input: [
                    .init(role: "user", content: [.init(text: combinedInput)])
                ],
                store: nil
            ))
        ]
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        applyOpenAICompatibleAuthHeaders(to: &request, token: token)

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

        do {
            return try decodeInsight(
                from: content,
                fallbackSource: sourceLabel(for: endpoint, model: resolvedModel)
            )
        } catch {
            return fallbackInsight(
                from: content,
                fallbackSource: sourceLabel(for: endpoint, model: resolvedModel)
            )
        }
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

    private func decodeInsightIfPresent(in data: Data, fallbackSource: String) throws -> AIStudyInsight? {
        if let decoded = try? JSONDecoder().decode(ResponseBody.self, from: data) {
            return AIStudyInsight(
                title: decoded.title,
                summary: decoded.summary,
                highlights: decoded.highlights,
                nextAction: decoded.nextAction,
                source: decoded.source ?? fallbackSource
            )
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }

        if let responseBody = responseBodyFromJSONObject(jsonObject) {
            return AIStudyInsight(
                title: responseBody.title,
                summary: responseBody.summary,
                highlights: responseBody.highlights,
                nextAction: responseBody.nextAction,
                source: responseBody.source ?? fallbackSource
            )
        }

        return nil
    }

    private func fallbackInsight(from content: String, fallbackSource: String) -> AIStudyInsight {
        let cleaned = cleanedPlainText(from: content)
        let lines = cleaned
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let title = fallbackTitle(from: lines.first) ?? "AI 解析"
        let highlights = fallbackHighlights(from: lines)
        let summary = fallbackSummary(from: cleaned, highlights: highlights)

        return AIStudyInsight(
            title: title,
            summary: summary,
            highlights: highlights,
            nextAction: "继续查看题目与解析，对照这 3 个要点再复盘一遍。",
            source: fallbackSource
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

    private func combinedResponsesPrompt(for question: Question, style: AIInsightStyle) -> String {
        """
        \(systemPrompt)

        \(userPrompt(for: question, style: style))
        """
    }

    private func endpointProtocol(for configuration: RemoteAIServiceConfiguration, endpoint: URL) -> EndpointProtocol {
        switch configuration.protocolPreference {
        case .responses:
            return .responses
        case .chatCompletions:
            return .openAICompatible
        case .custom:
            return .custom
        case .automatic:
            break
        }

        let path = endpoint.path.lowercased()
        let hasModel = sanitized(configuration.model) != nil

        if path.contains("/responses") {
            return .responses
        }

        if path.contains("/chat/completions") {
            return .openAICompatible
        }

        let host = endpoint.host()?.lowercased() ?? ""
        if host.contains("openai.com") || host.contains("deepseek.com") {
            return .openAICompatible
        }

        if hasModel, isLikelyResponsesBaseEndpoint(endpoint) {
            return .responses
        }

        if hasModel {
            return .openAICompatible
        }

        return .custom
    }

    private func resolvedResponsesEndpoint(from endpoint: URL) -> URL {
        let path = endpoint.path.lowercased()
        if path.contains("/responses") {
            return endpoint
        }

        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            return endpoint
        }

        if components.path.isEmpty || components.path == "/" {
            components.path = "/v1/responses"
        } else if components.path.hasSuffix("/v1") {
            components.path += "/responses"
        } else if components.path.hasSuffix("/v1/") {
            components.path += "responses"
        } else {
            components.path += components.path.hasSuffix("/") ? "responses" : "/responses"
        }

        return components.url ?? endpoint
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

        throw RemoteAIServiceError.requestFailed("当前 AI 接口需要填写模型名称。")
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

    private func isLikelyResponsesBaseEndpoint(_ endpoint: URL) -> Bool {
        let path = endpoint.path.lowercased()
        return path.isEmpty || path == "/" || path == "/v1" || path == "/v1/"
    }

    private func defaultResponsesReasoning(for model: String) -> String? {
        let normalizedModel = model.lowercased()
        if normalizedModel.hasPrefix("gpt-5") {
            return "xhigh"
        }
        return nil
    }

    private func extractedResponsesText(from data: Data) -> String? {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return extractedText(from: jsonObject)
    }

    private func responseBodyFromJSONObject(_ jsonObject: Any) -> ResponseBody? {
        if let dictionary = jsonObject as? [String: Any],
           let title = sanitized(dictionary["title"] as? String),
           let summary = sanitized(dictionary["summary"] as? String),
           let highlights = dictionary["highlights"] as? [String],
           highlights.count == 3,
           let nextAction = sanitized(dictionary["nextAction"] as? String) {
            return ResponseBody(
                title: title,
                summary: summary,
                highlights: highlights,
                nextAction: nextAction,
                source: sanitized(dictionary["source"] as? String)
            )
        }

        if let dictionary = jsonObject as? [String: Any] {
            for key in ["response", "data", "result", "message"] {
                if let nestedValue = dictionary[key],
                   let responseBody = responseBodyFromJSONObject(nestedValue) {
                    return responseBody
                }
            }

            for value in dictionary.values {
                if let responseBody = responseBodyFromJSONObject(value) {
                    return responseBody
                }
            }
        }

        if let array = jsonObject as? [Any] {
            for value in array {
                if let responseBody = responseBodyFromJSONObject(value) {
                    return responseBody
                }
            }
        }

        return nil
    }

    private func extractedText(from jsonObject: Any) -> String? {
        if let text = sanitized(jsonObject as? String) {
            return text
        }

        if let dictionary = jsonObject as? [String: Any] {
            if let directText = sanitized(dictionary["output_text"] as? String) {
                return directText
            }

            if let type = sanitized(dictionary["type"] as? String),
               type == "output_text",
               let text = sanitized(dictionary["text"] as? String) {
                return text
            }

            if let text = sanitized(dictionary["text"] as? String),
               dictionary["type"] == nil || sanitized(dictionary["type"] as? String) == "text" {
                return text
            }

            if let choices = dictionary["choices"] as? [[String: Any]] {
                for choice in choices {
                    if let message = choice["message"] as? [String: Any],
                       let content = extractedText(from: message) {
                        return content
                    }
                }
            }

            for key in ["response", "data", "result", "output", "message", "content"] {
                if let nestedValue = dictionary[key],
                   let text = extractedText(from: nestedValue) {
                    return text
                }
            }

            for value in dictionary.values {
                if let text = extractedText(from: value) {
                    return text
                }
            }
        }

        if let array = jsonObject as? [Any] {
            let texts = array.compactMap { extractedText(from: $0) }
            if !texts.isEmpty {
                return texts.joined(separator: "\n")
            }
        }

        return nil
    }

    private func normalizedJSONPayload(from content: String) -> String {
        let stripped = stripCodeFence(from: content)
        if let object = extractJSONObject(from: stripped) {
            return object
        }
        return stripped
    }

    private func cleanedPlainText(from content: String) -> String {
        stripCodeFence(from: content)
            .replacingOccurrences(of: "###", with: "")
            .replacingOccurrences(of: "##", with: "")
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fallbackTitle(from firstLine: String?) -> String? {
        guard let firstLine else { return nil }
        let normalized = normalizedBulletLine(firstLine)
        guard !normalized.isEmpty else { return nil }
        return String(normalized.prefix(20))
    }

    private func fallbackSummary(from cleaned: String, highlights: [String]) -> String {
        let summarySource = cleaned
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !summarySource.isEmpty {
            return String(summarySource.prefix(120))
        }

        return highlights.joined(separator: "；")
    }

    private func fallbackHighlights(from lines: [String]) -> [String] {
        var candidates = lines
            .map(normalizedBulletLine)
            .filter { !$0.isEmpty }

        if candidates.count < 3, let combined = lines.first {
            candidates.append(contentsOf: splitSentences(from: combined))
        }

        var unique: [String] = []
        for candidate in candidates {
            let normalized = String(candidate.prefix(36))
            if !normalized.isEmpty, !unique.contains(normalized) {
                unique.append(normalized)
            }
            if unique.count == 3 {
                break
            }
        }

        while unique.count < 3 {
            switch unique.count {
            case 0:
                unique.append("先看核心结论")
            case 1:
                unique.append("再核对答案依据")
            default:
                unique.append("最后复盘易错点")
            }
        }

        return unique
    }

    private func normalizedBulletLine(_ line: String) -> String {
        line
            .replacingOccurrences(of: #"^\s*[-*•]+\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\s*\d+[\.、]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func splitSentences(from text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: "。！？；\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
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

    private func applyOpenAICompatibleAuthHeaders(to request: inout URLRequest, token: String?) {
        guard let token = sanitized(token) else { return }

        request.setValue(authorizationHeaderValue(for: token), forHTTPHeaderField: "Authorization")

        guard let rawAPIKey = rawAPIKeyValue(from: token) else { return }
        request.setValue(rawAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue(rawAPIKey, forHTTPHeaderField: "x-goog-api-key")
    }

    private func rawAPIKeyValue(from token: String) -> String? {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        if parts.count == 2, parts[0].lowercased() == "bearer" {
            let raw = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            return raw.isEmpty ? nil : raw
        }

        return trimmed
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
