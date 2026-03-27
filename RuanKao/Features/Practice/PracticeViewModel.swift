import Foundation

@MainActor
final class PracticeViewModel: ObservableObject {
    @Published var selectedMode: PracticeMode
    @Published var selectedCategory: String? = nil
    @Published var selectedYear: Int? = nil
    @Published var searchText = ""
    @Published private(set) var selectedQuestionLimit: Int
    @Published private(set) var categories: [String] = []
    @Published private(set) var years: [Int] = []
    @Published private(set) var questions: [Question] = []
    @Published private(set) var currentIndex = 0
    @Published var selectedAnswers: Set<String> = []
    @Published var showAnalysis = false
    @Published var awaitingSubjectiveAssessment = false
    @Published private(set) var currentAnswerCorrect: Bool?
    @Published private(set) var finished = false
    @Published private(set) var remainingSeconds = 0
    @Published private(set) var answeredCount = 0
    @Published private(set) var correctCount = 0
    @Published private(set) var favoriteQuestionIDs: Set<Int64> = []
    @Published private(set) var aiInsight: AIStudyInsight?
    @Published private(set) var activeAIStyle: AIInsightStyle?
    @Published private(set) var isAILoading = false
    @Published var aiErrorMessage: String?
    @Published var errorMessage: String?

    private let questionRepository: QuestionRepositoryProtocol
    private let progressRepository: ProgressRepositoryProtocol
    private let aiStudyService: AIStudyServiceProtocol
    private let recordRecentSearch: (String?) -> Void
    private let recordRecentPractice: (PracticeMode, String?, Int?, String?) -> Void
    private var questionStartDate = Date()
    private var examTimer: Timer?

    init(
        questionRepository: QuestionRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol,
        aiStudyService: AIStudyServiceProtocol,
        recordRecentSearch: @escaping (String?) -> Void,
        recordRecentPractice: @escaping (PracticeMode, String?, Int?, String?) -> Void,
        preferredMode: PracticeMode,
        initialCategory: String? = nil,
        initialYear: Int? = nil,
        initialSearchText: String? = nil
    ) {
        self.questionRepository = questionRepository
        self.progressRepository = progressRepository
        self.aiStudyService = aiStudyService
        self.recordRecentSearch = recordRecentSearch
        self.recordRecentPractice = recordRecentPractice
        self.selectedMode = preferredMode
        self.selectedCategory = initialCategory
        self.selectedYear = initialYear
        self.searchText = initialSearchText ?? ""
        self.selectedQuestionLimit = Self.defaultQuestionLimit(for: preferredMode)
    }

    deinit {
        examTimer?.invalidate()
    }

    var currentQuestion: Question? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var progressText: String {
        guard !questions.isEmpty else { return "0/0" }
        return "\(min(currentIndex + 1, questions.count))/\(questions.count)"
    }

    var accuracyText: String {
        guard answeredCount > 0 else { return "--" }
        let accuracy = Double(correctCount) / Double(answeredCount)
        return accuracy.formatted(.percent.precision(.fractionLength(0)))
    }

    var hasActiveFilters: Bool {
        selectedCategory != nil || selectedYear != nil || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var currentQuestionIsFavorite: Bool {
        guard let currentQuestion else { return false }
        return favoriteQuestionIDs.contains(currentQuestion.id)
    }

    var availableQuestionLimits: [Int] {
        switch selectedMode {
        case .mockExam:
            return [25, 50, 100]
        case .sequential, .random, .wrongOnly:
            return [20, 50, 100, 200]
        }
    }

    func loadInitialData() {
        do {
            categories = try questionRepository.fetchCategories()
            years = try questionRepository.fetchAvailableYears()
            favoriteQuestionIDs = try questionRepository.fetchFavoriteQuestionIDs()
        } catch {
            errorMessage = error.localizedDescription
        }
        loadQuestions()
    }

    func loadQuestions() {
        stopTimer()
        errorMessage = nil

        do {
            let currentSearchText = normalizedSearchText
            questions = try questionRepository.loadPracticeQuestions(
                mode: selectedMode,
                limit: selectedQuestionLimit,
                category: selectedCategory,
                year: selectedYear,
                keyword: currentSearchText
            )

            currentIndex = 0
            answeredCount = 0
            correctCount = 0
            finished = questions.isEmpty
            resetQuestionState()

            if !questions.isEmpty {
                recordRecentPractice(selectedMode, selectedCategory, selectedYear, currentSearchText)
            }

            if selectedMode == .mockExam {
                remainingSeconds = 90 * 60
                startTimer()
            } else {
                remainingSeconds = 0
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func switchMode(_ mode: PracticeMode) {
        guard selectedMode != mode else { return }
        selectedMode = mode
        if !availableQuestionLimits.contains(selectedQuestionLimit) {
            selectedQuestionLimit = Self.defaultQuestionLimit(for: mode)
        }
        loadQuestions()
    }

    func selectCategory(_ category: String?) {
        selectedCategory = selectedCategory == category ? nil : category
        loadQuestions()
    }

    func selectYear(_ year: Int?) {
        selectedYear = selectedYear == year ? nil : year
        loadQuestions()
    }

    func applySearch() {
        recordRecentSearch(normalizedSearchText)
        loadQuestions()
    }

    func selectQuestionLimit(_ limit: Int) {
        guard selectedQuestionLimit != limit else { return }
        selectedQuestionLimit = limit
        loadQuestions()
    }

    func clearFilters() {
        selectedCategory = nil
        selectedYear = nil
        searchText = ""
        loadQuestions()
    }

    func toggleFavoriteForCurrentQuestion() {
        guard let currentQuestion else { return }
        let shouldFavorite = !favoriteQuestionIDs.contains(currentQuestion.id)

        do {
            try questionRepository.setFavorite(questionID: currentQuestion.id, isFavorite: shouldFavorite)
            if shouldFavorite {
                favoriteQuestionIDs.insert(currentQuestion.id)
            } else {
                favoriteQuestionIDs.remove(currentQuestion.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestAIInsight(style: AIInsightStyle) {
        guard let question = currentQuestion else { return }
        isAILoading = true
        aiErrorMessage = nil
        activeAIStyle = style

        Task { [weak self] in
            guard let self else { return }
            do {
                let insight = try await aiStudyService.generateInsight(for: question, style: style)
                await MainActor.run {
                    self.aiInsight = insight
                    self.isAILoading = false
                }
            } catch {
                await MainActor.run {
                    self.aiErrorMessage = error.localizedDescription
                    self.isAILoading = false
                }
            }
        }
    }

    func toggleSelection(_ label: String) {
        guard let question = currentQuestion, question.isObjective, !showAnalysis else { return }
        selectedAnswers = [label]
    }

    func submitObjectiveAnswer() {
        guard let question = currentQuestion, question.isObjective, !selectedAnswers.isEmpty, !showAnalysis else { return }

        let answers = Array(selectedAnswers).sorted()
        let isCorrect = Set(answers) == Set(question.correctAnswers)
        finalizeAttempt(question: question, selectedAnswers: answers, isCorrect: isCorrect)
    }

    func revealSubjectiveReference() {
        guard let question = currentQuestion, !question.isObjective, !showAnalysis else { return }
        showAnalysis = true
        awaitingSubjectiveAssessment = true
    }

    func markSubjectiveResult(isCorrect: Bool) {
        guard let question = currentQuestion, !question.isObjective, awaitingSubjectiveAssessment else { return }
        finalizeAttempt(question: question, selectedAnswers: [], isCorrect: isCorrect)
        awaitingSubjectiveAssessment = false
    }

    func nextQuestion() {
        guard currentIndex + 1 < questions.count else {
            finished = true
            stopTimer()
            return
        }

        currentIndex += 1
        resetQuestionState()
    }

    func restart() {
        loadQuestions()
    }

    func stopExamIfNeeded() {
        stopTimer()
    }

    private func finalizeAttempt(question: Question, selectedAnswers: [String], isCorrect: Bool) {
        do {
            let spentSeconds = max(1, Int(Date().timeIntervalSince(questionStartDate)))
            try progressRepository.recordAttempt(
                question: question,
                selectedAnswers: selectedAnswers,
                isCorrect: isCorrect,
                spentSeconds: spentSeconds
            )
            answeredCount += 1
            if isCorrect {
                correctCount += 1
            }
            currentAnswerCorrect = isCorrect
            showAnalysis = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resetQuestionState() {
        questionStartDate = Date()
        selectedAnswers = []
        showAnalysis = false
        awaitingSubjectiveAssessment = false
        currentAnswerCorrect = nil
        aiInsight = nil
        activeAIStyle = nil
        aiErrorMessage = nil
        isAILoading = false
    }

    private static func defaultQuestionLimit(for mode: PracticeMode) -> Int {
        switch mode {
        case .mockExam:
            return 25
        case .sequential, .random, .wrongOnly:
            return 20
        }
    }

    private func startTimer() {
        examTimer?.invalidate()
        examTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.remainingSeconds > 0 else {
                    self.finished = true
                    self.stopTimer()
                    return
                }
                self.remainingSeconds -= 1
            }
        }
        RunLoop.main.add(examTimer!, forMode: .common)
    }

    private func stopTimer() {
        examTimer?.invalidate()
        examTimer = nil
    }

    private var normalizedSearchText: String? {
        let value = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
