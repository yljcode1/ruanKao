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
