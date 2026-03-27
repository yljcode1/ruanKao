import Foundation

protocol ProgressRepositoryProtocol {
    func recordAttempt(
        question: Question,
        selectedAnswers: [String],
        isCorrect: Bool,
        spentSeconds: Int
    ) throws
}
