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

@MainActor
final class WrongBookViewModel: ObservableObject {
    @Published private(set) var items: [WrongQuestionItem] = []
    @Published var filter: WrongFilter = .unmastered
    @Published var errorMessage: String?

    private let questionRepository: QuestionRepositoryProtocol

    init(questionRepository: QuestionRepositoryProtocol) {
        self.questionRepository = questionRepository
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
        groupedItems.first?.0
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

    var groupedItems: [(String, [WrongQuestionItem])] {
        let grouped = Dictionary(grouping: filteredItems, by: \.primaryKnowledgePoint)
        return grouped
            .map { ($0.key, $0.value.sorted { $0.lastWrongAt > $1.lastWrongAt }) }
            .sorted { lhs, rhs in
                if lhs.1.count == rhs.1.count {
                    let lhsDate = lhs.1.first?.lastWrongAt ?? .distantPast
                    let rhsDate = rhs.1.first?.lastWrongAt ?? .distantPast
                    if lhsDate == rhsDate {
                        return lhs.0 < rhs.0
                    }
                    return lhsDate > rhsDate
                }
                return lhs.1.count > rhs.1.count
            }
    }

    func load() {
        do {
            errorMessage = nil
            items = try questionRepository.fetchWrongQuestions(includeMastered: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleMastered(_ item: WrongQuestionItem) {
        do {
            try questionRepository.markWrongQuestionMastered(
                questionID: item.question.id,
                isMastered: !item.isMastered
            )
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
