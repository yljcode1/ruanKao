import Foundation

protocol AnalyticsRepositoryProtocol: Sendable {
    func dashboardSnapshot() throws -> DashboardSnapshot
    func weakKnowledgePoints(limit: Int) throws -> [KnowledgeStat]
    func recentTrend(days: Int) throws -> [DailyTrend]
}
