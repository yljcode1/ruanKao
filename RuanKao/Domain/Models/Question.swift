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

enum QuestionSourceKind: String, Codable, Hashable {
    case official
    case adapted

    var title: String {
        switch self {
        case .official:
            return "真题"
        case .adapted:
            return "改编题"
        }
    }

    var icon: String {
        switch self {
        case .official:
            return "checkmark.seal"
        case .adapted:
            return "wand.and.stars"
        }
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

    var sourceKind: QuestionSourceKind {
        let adaptedKeywords = ["改编", "补充", "扩容", "芝士", "专题"]
        return adaptedKeywords.contains(where: stage.contains) ? .adapted : .official
    }

    var isAdapted: Bool {
        sourceKind == .adapted
    }

    var sourceBadgeTitle: String {
        sourceKind.title
    }

    var sourceBadgeIcon: String {
        sourceKind.icon
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
