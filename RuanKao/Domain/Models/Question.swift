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

enum SubjectiveReviewStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case needsWork
    case partial
    case mastered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .needsWork:
            return "需重练"
        case .partial:
            return "半掌握"
        case .mastered:
            return "已掌握"
        }
    }

    var icon: String {
        switch self {
        case .needsWork:
            return "arrow.triangle.2.circlepath"
        case .partial:
            return "minus.circle"
        case .mastered:
            return "checkmark.circle"
        }
    }

    var isCorrect: Bool {
        self == .mastered
    }
}

struct QuestionAnnotation: Codable, Hashable {
    let questionID: Int64
    let note: String
    let tags: [String]
    let subjectiveReviewStatus: SubjectiveReviewStatus?
    let updatedAt: Date

    init(
        questionID: Int64,
        note: String = "",
        tags: [String] = [],
        subjectiveReviewStatus: SubjectiveReviewStatus? = nil,
        updatedAt: Date = Date()
    ) {
        self.questionID = questionID
        self.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tags = Self.normalizedTags(tags)
        self.subjectiveReviewStatus = subjectiveReviewStatus
        self.updatedAt = updatedAt
    }

    var hasNote: Bool {
        !note.isEmpty
    }

    var hasTags: Bool {
        !tags.isEmpty
    }

    var isEmpty: Bool {
        !hasNote && !hasTags && subjectiveReviewStatus == nil
    }

    static func empty(questionID: Int64) -> QuestionAnnotation {
        QuestionAnnotation(questionID: questionID, updatedAt: .distantPast)
    }

    private static func normalizedTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for tag in tags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let lowered = trimmed.lowercased()
            if seen.insert(lowered).inserted {
                normalized.append(trimmed)
            }
        }

        return normalized
    }
}

struct FavoriteQuestionItem: Identifiable, Hashable {
    let question: Question
    var annotation: QuestionAnnotation

    var id: Int64 { question.id }
}
