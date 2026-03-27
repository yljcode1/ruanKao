import Foundation

enum PracticeMode: String, CaseIterable, Identifiable {
    case sequential
    case random
    case mockExam
    case wrongOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sequential:
            return "顺序刷题"
        case .random:
            return "随机刷题"
        case .mockExam:
            return "模拟考试"
        case .wrongOnly:
            return "错题重练"
        }
    }

    var subtitle: String {
        switch self {
        case .sequential:
            return "按年份与编号系统练习"
        case .random:
            return "打散知识点，提升检索能力"
        case .mockExam:
            return "限时训练，模拟真实考场"
        case .wrongOnly:
            return "聚焦薄弱点，快速提分"
        }
    }

    var icon: String {
        switch self {
        case .sequential:
            return "list.number"
        case .random:
            return "shuffle"
        case .mockExam:
            return "timer"
        case .wrongOnly:
            return "arrow.clockwise.circle"
        }
    }
}

struct PracticeDestination: Hashable {
    let mode: PracticeMode
    let category: String?
    let year: Int?
    let keyword: String?

    init(mode: PracticeMode, category: String? = nil, year: Int? = nil, keyword: String? = nil) {
        self.mode = mode
        self.category = category
        self.year = year
        self.keyword = keyword
    }
}

struct PracticeAttemptRecord: Codable, Hashable, Identifiable {
    let questionID: Int64
    let isCorrect: Bool
    let spentSeconds: Int

    var id: Int64 { questionID }
}

struct PracticeSessionSnapshot: Codable, Hashable, Identifiable {
    let modeRawValue: String
    let category: String?
    let year: Int?
    let keyword: String?
    let selectedQuestionLimit: Int
    let questionIDs: [Int64]
    let currentIndex: Int
    let answeredCount: Int
    let correctCount: Int
    let remainingSeconds: Int
    let attempts: [PracticeAttemptRecord]
    let updatedAt: Date

    var id: String { "active_practice_session" }

    var mode: PracticeMode {
        PracticeMode(rawValue: modeRawValue) ?? .sequential
    }

    var destination: PracticeDestination {
        PracticeDestination(mode: mode, category: category, year: year, keyword: keyword)
    }

    var progressText: String {
        guard !questionIDs.isEmpty else { return "0 / 0" }
        return "\(min(currentIndex + 1, questionIDs.count)) / \(questionIDs.count)"
    }

    var isResumable: Bool {
        !questionIDs.isEmpty && currentIndex < questionIDs.count
    }

    var subtitle: String {
        var parts: [String] = []

        if let year {
            parts.append("\(year)")
        }

        if let category {
            parts.append(category)
        }

        if let keyword {
            parts.append("搜：\(keyword)")
        }

        parts.append("进度 \(progressText)")

        if mode == .mockExam {
            let minutes = remainingSeconds / 60
            let seconds = remainingSeconds % 60
            parts.append(String(format: "剩余 %02d:%02d", minutes, seconds))
        }

        return parts.joined(separator: " · ")
    }
}
