import Foundation

protocol QuestionRepositoryProtocol: Sendable {
    func hasQuestionBank() throws -> Bool
    func seedIfNeeded() throws
    func loadPracticeQuestions(mode: PracticeMode, limit: Int, category: String?, year: Int?, keyword: String?) throws -> [Question]
    func fetchQuestions(questionIDs: [Int64]) throws -> [Question]
    func fetchSearchSuggestions(keyword: String, limit: Int) throws -> [String]
    func fetchCategories() throws -> [String]
    func fetchTopicSummaries(limit: Int?) throws -> [TopicSummary]
    func fetchAvailableYears() throws -> [Int]
    func fetchFavoriteQuestions() throws -> [Question]
    func fetchFavoriteQuestionIDs() throws -> Set<Int64>
    func fetchQuestionAnnotations(questionIDs: [Int64]) throws -> [Int64: QuestionAnnotation]
    func saveQuestionAnnotation(_ annotation: QuestionAnnotation) throws
    func setFavorite(questionID: Int64, isFavorite: Bool) throws
    func fetchWrongQuestions(includeMastered: Bool) throws -> [WrongQuestionItem]
    func markWrongQuestionMastered(questionID: Int64, isMastered: Bool) throws
}
