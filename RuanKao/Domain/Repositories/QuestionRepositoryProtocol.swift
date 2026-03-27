import Foundation

protocol QuestionRepositoryProtocol: Sendable {
    func seedIfNeeded() throws
    func loadPracticeQuestions(mode: PracticeMode, limit: Int, category: String?, year: Int?, keyword: String?) throws -> [Question]
    func fetchCategories() throws -> [String]
    func fetchTopicSummaries(limit: Int?) throws -> [TopicSummary]
    func fetchAvailableYears() throws -> [Int]
    func fetchFavoriteQuestions() throws -> [Question]
    func fetchFavoriteQuestionIDs() throws -> Set<Int64>
    func setFavorite(questionID: Int64, isFavorite: Bool) throws
    func fetchWrongQuestions(includeMastered: Bool) throws -> [WrongQuestionItem]
    func markWrongQuestionMastered(questionID: Int64, isMastered: Bool) throws
}
