import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    private struct LoadPayload {
        let snapshot: DashboardSnapshot
        let allTopicSummaries: [TopicSummary]
        let availableYears: [Int]
    }

    @Published private(set) var snapshot: DashboardSnapshot?
    @Published private(set) var availableYears: [Int] = []
    @Published private(set) var topicSummaries: [TopicSummary] = []
    @Published private(set) var totalTopicCount = 0
    @Published private(set) var totalTopicQuestionCount = 0
    @Published private(set) var studyPlan: [StudyPlanTask] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let analyticsRepository: AnalyticsRepositoryProtocol
    private let questionRepository: QuestionRepositoryProtocol
    private var loadTask: Task<Void, Never>?

    init(analyticsRepository: AnalyticsRepositoryProtocol, questionRepository: QuestionRepositoryProtocol) {
        self.analyticsRepository = analyticsRepository
        self.questionRepository = questionRepository
    }

    deinit {
        loadTask?.cancel()
    }

    func load() {
        loadTask?.cancel()
        isLoading = true
        errorMessage = nil

        let analyticsRepository = analyticsRepository
        let questionRepository = questionRepository

        loadTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<LoadPayload, Error> in
                do {
                    let snapshot = try analyticsRepository.dashboardSnapshot()
                    let allTopicSummaries = try questionRepository.fetchTopicSummaries(limit: nil)
                    let years = try questionRepository.fetchAvailableYears()
                    return .success(
                        LoadPayload(
                            snapshot: snapshot,
                            allTopicSummaries: allTopicSummaries,
                            availableYears: years
                        )
                    )
                } catch {
                    return .failure(error)
                }
            }.value

            guard let self, !Task.isCancelled else { return }

            self.isLoading = false

            switch result {
            case .success(let payload):
                self.snapshot = payload.snapshot
                self.availableYears = payload.availableYears
                self.topicSummaries = Array(payload.allTopicSummaries.prefix(6))
                self.totalTopicCount = payload.allTopicSummaries.count
                self.totalTopicQuestionCount = payload.allTopicSummaries.map(\.questionCount).reduce(0, +)
                self.studyPlan = self.makeStudyPlan(from: payload.snapshot)
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func makeStudyPlan(from snapshot: DashboardSnapshot) -> [StudyPlanTask] {
        var tasks: [StudyPlanTask] = []

        if snapshot.todayPracticeCount < 10 {
            tasks.append(
                StudyPlanTask(
                    title: "先完成今天的基础题量",
                    subtitle: "建议再做 \(10 - snapshot.todayPracticeCount) 道顺序题，保持连续性。",
                    icon: "target",
                    tintHexTag: "primary"
                )
            )
        }

        if let weakPoint = snapshot.weakKnowledgePoints.first {
            tasks.append(
                StudyPlanTask(
                    title: "重点补强 \(weakPoint.name)",
                    subtitle: "当前正确率 \(weakPoint.accuracy.formatted(.percent.precision(.fractionLength(0))))，优先刷相关错题。",
                    icon: "bolt.heart",
                    tintHexTag: "danger"
                )
            )
        }

        if !snapshot.todayCheckedIn {
            tasks.append(
                StudyPlanTask(
                    title: "今天还没打卡",
                    subtitle: "做任意 1 道题就会自动累计连续学习天数。",
                    icon: "calendar.badge.plus",
                    tintHexTag: "primary"
                )
            )
        }

        if snapshot.overallAccuracy >= 0.7 {
            tasks.append(
                StudyPlanTask(
                    title: "安排一次模拟考试",
                    subtitle: "综合正确率不错，可以开始做限时训练提升节奏感。",
                    icon: "timer",
                    tintHexTag: "accent"
                )
            )
        } else {
            tasks.append(
                StudyPlanTask(
                    title: "做一轮随机题检索训练",
                    subtitle: "把知识点打散，检验你是否真的记住了。",
                    icon: "shuffle",
                    tintHexTag: "secondary"
                )
            )
        }

        return tasks
    }
}
