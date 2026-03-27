import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published private(set) var weakPoints: [KnowledgeStat] = []
    @Published private(set) var trend: [DailyTrend] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let analyticsRepository: AnalyticsRepositoryProtocol
    private var loadTask: Task<Void, Never>?
    private var hasLoaded = false

    init(analyticsRepository: AnalyticsRepositoryProtocol) {
        self.analyticsRepository = analyticsRepository
    }

    deinit {
        loadTask?.cancel()
    }

    func loadIfNeeded() {
        guard !hasLoaded, !isLoading else { return }
        load(force: false)
    }

    func load(force: Bool = false) {
        guard force || !hasLoaded else { return }
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil

        let repository = analyticsRepository
        loadTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<([KnowledgeStat], [DailyTrend]), Error> in
                do {
                    return .success((
                        try repository.weakKnowledgePoints(limit: 8),
                        try repository.recentTrend(days: 14)
                    ))
                } catch {
                    return .failure(error)
                }
            }.value

            guard let self, !Task.isCancelled else { return }

            self.isLoading = false

            switch result {
            case .success(let payload):
                self.hasLoaded = true
                self.weakPoints = payload.0
                self.trend = payload.1
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }
}
