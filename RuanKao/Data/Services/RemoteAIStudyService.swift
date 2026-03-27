import Foundation

struct RemoteAIServiceConfiguration {
    let endpoint: URL?
    let bearerToken: String?
}

enum RemoteAIServiceError: LocalizedError {
    case notConfigured
    case badServerResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI 远程服务尚未配置。"
        case .badServerResponse:
            return "AI 服务返回了无法识别的结果。"
        }
    }
}

final class RemoteAIStudyService: AIStudyServiceProtocol {
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

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let bearerToken = configuration.bearerToken, !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(RequestBody(style: style.rawValue, question: question))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw RemoteAIServiceError.badServerResponse
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        return AIStudyInsight(
            title: decoded.title,
            summary: decoded.summary,
            highlights: decoded.highlights,
            nextAction: decoded.nextAction,
            source: decoded.source ?? "远程 AI"
        )
    }
}
