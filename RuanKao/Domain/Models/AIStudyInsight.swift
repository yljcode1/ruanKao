import Foundation

enum AIInsightStyle: String, Identifiable, CaseIterable, Hashable, Codable {
    case explanation
    case similarQuestion
    case essayOutline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explanation:
            return "AI 讲解"
        case .similarQuestion:
            return "AI 相似题"
        case .essayOutline:
            return "AI 提纲"
        }
    }

    var icon: String {
        switch self {
        case .explanation:
            return "sparkles"
        case .similarQuestion:
            return "square.stack.3d.up"
        case .essayOutline:
            return "list.bullet.rectangle.portrait"
        }
    }
}

struct AIStudyInsight: Hashable, Codable {
    let title: String
    let summary: String
    let highlights: [String]
    let nextAction: String
    let source: String
}
