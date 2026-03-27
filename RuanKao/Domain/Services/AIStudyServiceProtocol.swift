import Foundation

protocol AIStudyServiceProtocol: Sendable {
    func generateInsight(for question: Question, style: AIInsightStyle) async throws -> AIStudyInsight
}
