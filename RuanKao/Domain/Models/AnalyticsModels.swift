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

struct StudyPlanTask: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let tintHexTag: String
}
