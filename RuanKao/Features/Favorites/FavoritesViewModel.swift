import Foundation

@MainActor
final class FavoritesViewModel: ObservableObject {
    private struct LoadPayload {
        let questions: [Question]
        let annotations: [Int64: QuestionAnnotation]
    }

    @Published private(set) var items: [FavoriteQuestionItem] = []
    @Published private(set) var isLoading = false
    @Published var selectedTag: String?
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

    var count: Int {
        items.count
    }

    var availableTags: [String] {
        var counts: [String: Int] = [:]

        for item in items {
            for tag in item.annotation.tags {
                counts[tag, default: 0] += 1
            }
        }

        return counts.keys.sorted { lhs, rhs in
            let lhsCount = counts[lhs] ?? 0
            let rhsCount = counts[rhs] ?? 0
            if lhsCount == rhsCount {
                return lhs.localizedCompare(rhs) == .orderedAscending
            }
            return lhsCount > rhsCount
        }
    }

    var filteredItems: [FavoriteQuestionItem] {
        guard let selectedTag else { return items }
        return items.filter { $0.annotation.tags.contains(selectedTag) }
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
            let result = await Task.detached(priority: .userInitiated) { () -> Result<LoadPayload, Error> in
                do {
                    let questions = try repository.fetchFavoriteQuestions()
                    let annotations = try repository.fetchQuestionAnnotations(questionIDs: questions.map(\.id))
                    return .success(LoadPayload(questions: questions, annotations: annotations))
                } catch {
                    return .failure(error)
                }
            }.value

            guard let self, !Task.isCancelled else { return }

            self.isLoading = false

            switch result {
            case .success(let payload):
                self.hasLoaded = true
                self.items = payload.questions.map { question in
                    FavoriteQuestionItem(
                        question: question,
                        annotation: payload.annotations[question.id] ?? .empty(questionID: question.id)
                    )
                }
                self.normalizeSelectedTag()
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func selectTag(_ tag: String?) {
        if selectedTag == tag {
            selectedTag = nil
        } else {
            selectedTag = tag
        }
    }

    func removeFavorite(questionID: Int64) {
        do {
            try questionRepository.setFavorite(questionID: questionID, isFavorite: false)
            items.removeAll { $0.id == questionID }
            normalizeSelectedTag()
            dataDidChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveAnnotation(questionID: Int64, tags: [String], note: String) {
        guard let index = items.firstIndex(where: { $0.id == questionID }) else { return }

        do {
            let annotation = QuestionAnnotation(
                questionID: questionID,
                note: note,
                tags: tags,
                subjectiveReviewStatus: items[index].annotation.subjectiveReviewStatus,
                updatedAt: Date()
            )
            try questionRepository.saveQuestionAnnotation(annotation)
            items[index].annotation = annotation.isEmpty ? .empty(questionID: questionID) : annotation
            normalizeSelectedTag()
            dataDidChange()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func normalizeSelectedTag() {
        if let selectedTag, !availableTags.contains(selectedTag) {
            self.selectedTag = nil
        }
    }
}
