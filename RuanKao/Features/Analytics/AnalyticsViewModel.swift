import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published private(set) var weakPoints: [KnowledgeStat] = []
    @Published private(set) var trend: [DailyTrend] = []
    @Published var errorMessage: String?

    private let analyticsRepository: AnalyticsRepositoryProtocol

    init(analyticsRepository: AnalyticsRepositoryProtocol) {
        self.analyticsRepository = analyticsRepository
    }

    func load() {
        do {
            errorMessage = nil
            weakPoints = try analyticsRepository.weakKnowledgePoints(limit: 8)
            trend = try analyticsRepository.recentTrend(days: 14)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
