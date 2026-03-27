import Foundation

protocol AIStudyServiceProtocol {
    func generateInsight(for question: Question, style: AIInsightStyle) async throws -> AIStudyInsight
}
