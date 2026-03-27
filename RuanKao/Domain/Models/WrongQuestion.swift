import Foundation

struct WrongQuestionItem: Identifiable, Hashable {
    let id: Int64
    let question: Question
    let wrongCount: Int
    let lastWrongAt: Date
    let isMastered: Bool

    var primaryKnowledgePoint: String {
        question.knowledgePoints.first ?? "未分类"
    }
}
