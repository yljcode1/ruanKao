import Foundation

@MainActor
final class FavoritesViewModel: ObservableObject {
    @Published private(set) var questions: [Question] = []
    @Published var errorMessage: String?

    private let questionRepository: QuestionRepositoryProtocol

    init(questionRepository: QuestionRepositoryProtocol) {
        self.questionRepository = questionRepository
    }

    var count: Int {
        questions.count
    }

    func load() {
        do {
            errorMessage = nil
            questions = try questionRepository.fetchFavoriteQuestions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFavorite(questionID: Int64) {
        do {
            try questionRepository.setFavorite(questionID: questionID, isFavorite: false)
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
