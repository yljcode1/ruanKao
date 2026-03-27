import Foundation

enum WrongFilter: String, CaseIterable, Identifiable {
    case all
    case unmastered
    case mastered

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .unmastered:
            return "未掌握"
        case .mastered:
            return "已掌握"
        }
    }
}

enum WrongSortMode: String, CaseIterable, Identifiable {
    case knowledgePoint
    case recent
    case highRisk

    var id: String { rawValue }

    var title: String {
        switch self {
        case .knowledgePoint:
            return "按知识点"
        case .recent:
            return "最近连错"
        case .highRisk:
            return "高危错题"
        }
    }
}

struct WrongQuestionSection: Identifiable, Hashable {
    let title: String
    let subtitle: String?
    let items: [WrongQuestionItem]

    var id: String { title }
}

@MainActor
final class WrongBookViewModel: ObservableObject {
    @Published private(set) var items: [WrongQuestionItem] = []
    @Published var filter: WrongFilter = .unmastered
    @Published var sortMode: WrongSortMode = .knowledgePoint
    @Published var selectedKnowledgePoint: String?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let questionRepository: QuestionRepositoryProtocol
    private let dataDidChange: () -> Void
    private var loadTask: Task<Void, Never>?
    private var hasLoaded = false

    init(
        questionRepository: QuestionRepositoryProtocol,
        dataDidChange: @escaping () -> Void = {}
    ) {
        self.questionRepository = questionRepository
        self.dataDidChange = dataDidChange
    }

    deinit {
        loadTask?.cancel()
    }

    var totalCount: Int {
        items.count
    }

    var masteredCount: Int {
        items.filter(\.isMastered).count
    }

    var unmasteredCount: Int {
        items.filter { !$0.isMastered }.count
    }

    var hottestKnowledgePoint: String? {
        knowledgePointOptions.first
    }

    var knowledgePointOptions: [String] {
        let counts = Dictionary(grouping: filteredItems, by: \.primaryKnowledgePoint)
            .mapValues(\.count)

        return counts.keys.sorted { lhs, rhs in
            let lhsCount = counts[lhs] ?? 0
            let rhsCount = counts[rhs] ?? 0
            if lhsCount == rhsCount {
                return lhs.localizedCompare(rhs) == .orderedAscending
            }
            return lhsCount > rhsCount
        }
    }

    var filteredItems: [WrongQuestionItem] {
        switch filter {
        case .all:
            return items
        case .unmastered:
            return items.filter { !$0.isMastered }
        case .mastered:
            return items.filter(\.isMastered)
        }
    }

    var visibleItems: [WrongQuestionItem] {
        guard let selectedKnowledgePoint else { return filteredItems }
        return filteredItems.filter { $0.primaryKnowledgePoint == selectedKnowledgePoint }
    }

    var displaySections: [WrongQuestionSection] {
        switch sortMode {
        case .knowledgePoint:
            let grouped = Dictionary(grouping: visibleItems, by: \.primaryKnowledgePoint)
            return grouped
                .map { key, value in
                    WrongQuestionSection(
                        title: key,
                        subtitle: "按知识点集中回看，适合连刷补短板",
                        items: value.sorted { lhs, rhs in
                            if lhs.wrongCount == rhs.wrongCount {
                                return lhs.lastWrongAt > rhs.lastWrongAt
                            }
                            return lhs.wrongCount > rhs.wrongCount
                        }
                    )
                }
                .sorted { lhs, rhs in
                    if lhs.items.count == rhs.items.count {
                        return lhs.title.localizedCompare(rhs.title) == .orderedAscending
                    }
                    return lhs.items.count > rhs.items.count
                }
        case .recent:
            return [
                WrongQuestionSection(
                    title: selectedKnowledgePoint ?? "最近连错",
                    subtitle: "优先处理最近几次刚错过的题",
                    items: visibleItems.sorted { $0.lastWrongAt > $1.lastWrongAt }
                )
            ]
        case .highRisk:
            return [
                WrongQuestionSection(
                    title: selectedKnowledgePoint ?? "高危错题",
                    subtitle: "错误次数越多越靠前，最值得优先重练",
                    items: visibleItems.sorted { lhs, rhs in
                        if lhs.wrongCount == rhs.wrongCount {
                            return lhs.lastWrongAt > rhs.lastWrongAt
                        }
                        return lhs.wrongCount > rhs.wrongCount
                    }
                )
            ]
        }
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

        let repository = questionRepository
        loadTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<[WrongQuestionItem], Error> in
                do {
                    return .success(try repository.fetchWrongQuestions(includeMastered: true))
                } catch {
                    return .failure(error)
                }
            }.value

            guard let self, !Task.isCancelled else { return }

            self.isLoading = false

            switch result {
            case .success(let items):
                self.hasLoaded = true
                self.items = items
                self.normalizeSelectedKnowledgePoint()
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func selectKnowledgePoint(_ knowledgePoint: String?) {
        if selectedKnowledgePoint == knowledgePoint {
            selectedKnowledgePoint = nil
        } else {
            selectedKnowledgePoint = knowledgePoint
        }
    }

    func toggleMastered(_ item: WrongQuestionItem) {
        do {
            try questionRepository.markWrongQuestionMastered(
                questionID: item.question.id,
                isMastered: !item.isMastered
            )
            guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
            items[index] = WrongQuestionItem(
                id: item.id,
                question: item.question,
                wrongCount: item.wrongCount,
                lastWrongAt: item.lastWrongAt,
                isMastered: !item.isMastered
            )
            normalizeSelectedKnowledgePoint()
            dataDidChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func normalizeSelectedKnowledgePoint() {
        if let selectedKnowledgePoint, !knowledgePointOptions.contains(selectedKnowledgePoint) {
            self.selectedKnowledgePoint = nil
        }
    }
}
