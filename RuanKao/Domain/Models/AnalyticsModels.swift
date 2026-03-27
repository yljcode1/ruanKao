import Foundation

struct KnowledgeStat: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let practicedCount: Int
    let accuracy: Double
}

struct DailyTrend: Identifiable, Hashable {
    let date: Date
    let practicedCount: Int
    let accuracy: Double

    var id: Date { date }
}

struct DashboardSnapshot: Hashable {
    let totalQuestions: Int
    let answeredQuestions: Int
    let todayPracticeCount: Int
    let overallAccuracy: Double
    let currentStreak: Int
    let longestStreak: Int
    let todayCheckedIn: Bool
    let weakKnowledgePoints: [KnowledgeStat]
    let recentTrend: [DailyTrend]
}

struct PracticeKnowledgeGap: Identifiable, Hashable {
    let name: String
    let wrongCount: Int

    var id: String { name }
}

struct PracticeFinishSummary: Hashable {
    let totalQuestions: Int
    let answeredCount: Int
    let correctCount: Int
    let scoreEarned: Double
    let totalScore: Double
    let totalSpentSeconds: Int
    let remainingSeconds: Int
    let wrongKnowledgePoints: [PracticeKnowledgeGap]
    let recommendation: String

    var accuracy: Double {
        guard answeredCount > 0 else { return 0 }
        return Double(correctCount) / Double(answeredCount)
    }

    var averageSpentSeconds: Int {
        guard answeredCount > 0 else { return 0 }
        return totalSpentSeconds / answeredCount
    }
}

struct StudyPlanTask: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tintHexTag: String
    let destination: PracticeDestination
}
