import Foundation

final class HybridAIStudyService: AIStudyServiceProtocol {
    private let remote: RemoteAIStudyService
    private let fallback: MockAIStudyService

    init(remote: RemoteAIStudyService, fallback: MockAIStudyService = MockAIStudyService()) {
        self.remote = remote
        self.fallback = fallback
    }

    func generateInsight(for question: Question, style: AIInsightStyle) async throws -> AIStudyInsight {
        do {
            return try await remote.generateInsight(for: question, style: style)
        } catch {
            if case RemoteAIServiceError.notConfigured = error {
                return try await fallback.generateInsight(for: question, style: style)
            }
            throw error
        }
    }
}
