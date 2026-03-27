import Foundation

protocol AnalyticsRepositoryProtocol {
    func dashboardSnapshot() throws -> DashboardSnapshot
    func weakKnowledgePoints(limit: Int) throws -> [KnowledgeStat]
    func recentTrend(days: Int) throws -> [DailyTrend]
}
