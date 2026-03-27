import Foundation

enum QuestionType: String, Codable, CaseIterable {
    case singleChoice
    case caseStudy
    case essay

    var title: String {
        switch self {
        case .singleChoice:
            return "选择题"
        case .caseStudy:
            return "案例题"
        case .essay:
            return "论文题"
        }
    }
}

struct QuestionOption: Codable, Hashable, Identifiable {
    let id: String
    let label: String
    let content: String

    init(label: String, content: String) {
        self.id = label
        self.label = label
        self.content = content
    }
}

struct Question: Codable, Hashable, Identifiable {
    let id: Int64
    let year: Int
    let stage: String
    let type: QuestionType
    let category: String
    let knowledgePoints: [String]
    let stem: String
    let options: [QuestionOption]
    let correctAnswers: [String]
    let analysis: String
    let score: Double
    let estimatedMinutes: Int

    var sourceText: String {
        "\(year) · \(stage)"
    }

    var answerSummary: String {
        correctAnswers.joined(separator: "、")
    }

    var isObjective: Bool {
        type == .singleChoice
    }
}

struct TopicSummary: Hashable, Identifiable {
    let category: String
    let questionCount: Int
    let latestYear: Int
    let objectiveCount: Int
    let subjectiveCount: Int

    var id: String { category }
}
