import Foundation

@MainActor
final class PracticeViewModel: ObservableObject {
    private struct InitialLoadPayload {
        let categories: [String]
        let years: [Int]
        let favoriteQuestionIDs: Set<Int64>
        let restoredSession: RestoredSessionPayload?
    }

    private struct RestoredSessionPayload {
        let snapshot: PracticeSessionSnapshot
        let questionPayload: QuestionLoadPayload
    }

    private struct QuestionLoadPayload {
        let questions: [Question]
        let annotations: [Int64: QuestionAnnotation]
    }

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
    @Published private(set) var isLoadingInitialData = false
    @Published private(set) var isLoadingQuestions = false
    @Published private(set) var finishSummary: PracticeFinishSummary?
    @Published var subjectiveNoteDraft = ""
    @Published private(set) var currentSubjectiveReviewStatus: SubjectiveReviewStatus?
    @Published var aiErrorMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var searchSuggestions: [String] = []

    private let questionRepository: QuestionRepositoryProtocol
    private let progressRepository: ProgressRepositoryProtocol
    private let aiStudyService: AIStudyServiceProtocol
    private let practiceSessionStore: PracticeSessionStore
    private let notifyStudyDataChanged: () -> Void
    private let recordRecentSearch: (String?) -> Void
    private let recordRecentPractice: (PracticeMode, String?, Int?, String?) -> Void
    private let resumeSessionSnapshot: PracticeSessionSnapshot?
    private var annotationsByQuestionID: [Int64: QuestionAnnotation] = [:]
    private var sessionAttempts: [PracticeAttemptRecord] = []
    private var questionStartDate = Date()
    private var examTimer: Timer?
    private var suggestionTask: Task<Void, Never>?
    private var initialLoadTask: Task<Void, Never>?
    private var questionLoadTask: Task<Void, Never>?
    private var aiInsightTask: Task<Void, Never>?
    private var aiPrefetchTask: Task<Void, Never>?
    private var searchSuggestionCache: [String: [String]] = [:]
    private let searchSuggestionLimit = 6
    private var latestQuestionLoadID = UUID()
    private var latestAIInsightRequestID = UUID()
    private var hasLoadedInitialData = false

    init(
        questionRepository: QuestionRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol,
        aiStudyService: AIStudyServiceProtocol,
        practiceSessionStore: PracticeSessionStore,
        notifyStudyDataChanged: @escaping () -> Void,
        recordRecentSearch: @escaping (String?) -> Void,
        recordRecentPractice: @escaping (PracticeMode, String?, Int?, String?) -> Void,
        preferredMode: PracticeMode,
        initialCategory: String? = nil,
        initialYear: Int? = nil,
        initialSearchText: String? = nil,
        resumeSessionSnapshot: PracticeSessionSnapshot? = nil
    ) {
        self.questionRepository = questionRepository
        self.progressRepository = progressRepository
        self.aiStudyService = aiStudyService
        self.practiceSessionStore = practiceSessionStore
        self.notifyStudyDataChanged = notifyStudyDataChanged
        self.recordRecentSearch = recordRecentSearch
        self.recordRecentPractice = recordRecentPractice
        self.resumeSessionSnapshot = resumeSessionSnapshot

        let effectiveMode = resumeSessionSnapshot?.mode ?? preferredMode
        let effectiveCategory = resumeSessionSnapshot?.category ?? initialCategory
        let effectiveYear = resumeSessionSnapshot?.year ?? initialYear
        let effectiveSearchText = resumeSessionSnapshot?.keyword ?? initialSearchText ?? ""
        let effectiveLimit = resumeSessionSnapshot?.selectedQuestionLimit ?? Self.defaultQuestionLimit(for: effectiveMode)

        selectedMode = effectiveMode
        selectedCategory = effectiveCategory
        selectedYear = effectiveYear
        searchText = effectiveSearchText
        selectedQuestionLimit = effectiveLimit
    }

    deinit {
        examTimer?.invalidate()
        suggestionTask?.cancel()
        initialLoadTask?.cancel()
        questionLoadTask?.cancel()
        aiInsightTask?.cancel()
        aiPrefetchTask?.cancel()
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

    func loadInitialDataIfNeeded() {
        guard !hasLoadedInitialData, !isLoadingInitialData else { return }
        loadInitialData()
    }

    func loadInitialData() {
        initialLoadTask?.cancel()
        questionLoadTask?.cancel()

        errorMessage = nil
        isLoadingInitialData = true
        isLoadingQuestions = false

        let repository = questionRepository
        let resumeSnapshot = resumeSessionSnapshot
        initialLoadTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<InitialLoadPayload, Error> in
                do {
                    let categories = try repository.fetchCategories()
                    let years = try repository.fetchAvailableYears()
                    let favoriteQuestionIDs = try repository.fetchFavoriteQuestionIDs()

                    let restoredSession: RestoredSessionPayload?
                    if let resumeSnapshot, resumeSnapshot.isResumable {
                        let restoredQuestions = try repository.fetchQuestions(questionIDs: resumeSnapshot.questionIDs)
                        let restoredAnnotations = try repository.fetchQuestionAnnotations(questionIDs: restoredQuestions.map(\.id))
                        restoredSession = restoredQuestions.isEmpty
                            ? nil
                            : RestoredSessionPayload(
                                snapshot: resumeSnapshot,
                                questionPayload: QuestionLoadPayload(
                                    questions: restoredQuestions,
                                    annotations: restoredAnnotations
                                )
                            )
                    } else {
                        restoredSession = nil
                    }

                    return .success(
                        InitialLoadPayload(
                            categories: categories,
                            years: years,
                            favoriteQuestionIDs: favoriteQuestionIDs,
                            restoredSession: restoredSession
                        )
                    )
                } catch {
                    return .failure(error)
                }
            }.value

            guard let self, !Task.isCancelled else { return }

            self.isLoadingInitialData = false

            switch result {
            case .success(let payload):
                self.hasLoadedInitialData = true
                self.categories = payload.categories
                self.years = payload.years
                self.favoriteQuestionIDs = payload.favoriteQuestionIDs

                if let restoredSession = payload.restoredSession {
                    self.applyRestoredSession(restoredSession)
                } else {
                    if self.resumeSessionSnapshot != nil {
                        self.practiceSessionStore.clear()
                    }
                    self.loadQuestions()
                }
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func loadQuestions() {
        questionLoadTask?.cancel()
        stopTimer()
        errorMessage = nil
        isLoadingQuestions = true
        finished = false
        remainingSeconds = 0
        questions = []
        currentIndex = 0
        answeredCount = 0
        correctCount = 0
        finishSummary = nil
        sessionAttempts = []
        annotationsByQuestionID = [:]
        resetQuestionState()

        let currentMode = selectedMode
        let currentLimit = selectedQuestionLimit
        let currentCategory = selectedCategory
        let currentYear = selectedYear
        let currentSearchText = normalizedSearchText
        let repository = questionRepository
        let loadID = UUID()
        latestQuestionLoadID = loadID

        questionLoadTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { () -> Result<QuestionLoadPayload, Error> in
                do {
                    let questions = try repository.loadPracticeQuestions(
                        mode: currentMode,
                        limit: currentLimit,
                        category: currentCategory,
                        year: currentYear,
                        keyword: currentSearchText
                    )
                    let annotations = try repository.fetchQuestionAnnotations(questionIDs: questions.map(\.id))
                    return .success(QuestionLoadPayload(questions: questions, annotations: annotations))
                } catch {
                    return .failure(error)
                }
            }.value

            guard let self, !Task.isCancelled, self.latestQuestionLoadID == loadID else { return }

            self.isLoadingQuestions = false

            switch result {
            case .success(let payload):
                self.questions = payload.questions
                self.annotationsByQuestionID = payload.annotations
                self.currentIndex = 0
                self.answeredCount = 0
                self.correctCount = 0
                self.finished = payload.questions.isEmpty
                self.resetQuestionState()

                if !payload.questions.isEmpty {
                    self.recordRecentPractice(currentMode, currentCategory, currentYear, currentSearchText)
                }

                if currentMode == .mockExam {
                    self.remainingSeconds = 90 * 60
                    self.startTimer()
                } else {
                    self.remainingSeconds = 0
                }

                self.persistPracticeSession()
            case .failure(let error):
                self.errorMessage = error.localizedDescription
            }
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
        dismissSearchSuggestions()
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
        dismissSearchSuggestions()
        loadQuestions()
    }

    func handleSearchTextChanged() {
        suggestionTask?.cancel()

        guard let keyword = normalizedSearchText else {
            searchSuggestions = []
            return
        }

        let cacheKey = keyword.lowercased()
        if let cachedSuggestions = searchSuggestionCache[cacheKey] {
            searchSuggestions = cachedSuggestions
            return
        }

        suggestionTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: 180_000_000)
            guard !Task.isCancelled else { return }

            let repository = self.questionRepository
            let suggestionLimit = self.searchSuggestionLimit
            let suggestions = (try? await Task.detached(priority: .userInitiated) {
                try repository.fetchSearchSuggestions(keyword: keyword, limit: suggestionLimit)
            }.value) ?? []

            guard !Task.isCancelled else { return }
            guard self.normalizedSearchText?.caseInsensitiveCompare(keyword) == .orderedSame else { return }

            self.searchSuggestionCache[cacheKey] = suggestions
            self.searchSuggestions = suggestions
        }
    }

    func selectSearchSuggestion(_ suggestion: String) {
        searchText = suggestion
        applySearch()
    }

    func dismissSearchSuggestions() {
        suggestionTask?.cancel()
        searchSuggestions = []
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
            notifyStudyDataChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestAIInsight(style: AIInsightStyle) {
        guard let question = currentQuestion else { return }
        aiInsightTask?.cancel()

        let requestID = UUID()
        let questionID = question.id
        latestAIInsightRequestID = requestID

        isAILoading = true
        aiInsight = nil
        aiErrorMessage = nil
        activeAIStyle = style

        aiInsightTask = Task { [weak self] in
            guard let self else { return }
            do {
                let insight = try await aiStudyService.generateInsight(for: question, style: style)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.latestAIInsightRequestID == requestID else { return }
                    guard self.currentQuestion?.id == questionID else { return }
                    self.aiInsight = insight
                    self.isAILoading = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard self.latestAIInsightRequestID == requestID else { return }
                    self.isAILoading = false
                }
            } catch {
                await MainActor.run {
                    guard self.latestAIInsightRequestID == requestID else { return }
                    guard self.currentQuestion?.id == questionID else { return }
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
        finalizeAttempt(question: question, selectedAnswers: answers, isCorrect: isCorrect, subjectiveReviewStatus: nil)
    }

    func revealSubjectiveReference() {
        guard let question = currentQuestion, !question.isObjective, !showAnalysis else { return }
        showAnalysis = true
        awaitingSubjectiveAssessment = true
        prefetchDefaultAIInsight(for: question)
    }

    func markSubjectiveResult(_ status: SubjectiveReviewStatus) {
        guard let question = currentQuestion, !question.isObjective, awaitingSubjectiveAssessment else { return }
        finalizeAttempt(question: question, selectedAnswers: [], isCorrect: status.isCorrect, subjectiveReviewStatus: status)
        awaitingSubjectiveAssessment = false
    }

    func saveSubjectiveNote() {
        guard let question = currentQuestion, !question.isObjective else { return }

        do {
            let existingAnnotation = annotationsByQuestionID[question.id] ?? .empty(questionID: question.id)
            let annotation = QuestionAnnotation(
                questionID: question.id,
                note: subjectiveNoteDraft,
                tags: existingAnnotation.tags,
                subjectiveReviewStatus: currentSubjectiveReviewStatus,
                updatedAt: Date()
            )
            try questionRepository.saveQuestionAnnotation(annotation)
            annotationsByQuestionID[question.id] = annotation.isEmpty ? .empty(questionID: question.id) : annotation
            currentSubjectiveReviewStatus = annotation.subjectiveReviewStatus
            notifyStudyDataChanged()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func nextQuestion() {
        guard currentIndex + 1 < questions.count else {
            finished = true
            stopTimer()
            finalizeSessionIfNeeded()
            return
        }

        currentIndex += 1
        resetQuestionState()
        persistPracticeSession()
    }

    func restart() {
        loadQuestions()
    }

    func stopExamIfNeeded() {
        persistPracticeSession()
        stopTimer()
    }

    private func applyRestoredSession(_ restoredSession: RestoredSessionPayload) {
        questions = restoredSession.questionPayload.questions
        annotationsByQuestionID = restoredSession.questionPayload.annotations
        currentIndex = min(restoredSession.snapshot.currentIndex, max(questions.count - 1, 0))
        answeredCount = min(restoredSession.snapshot.answeredCount, questions.count)
        correctCount = min(restoredSession.snapshot.correctCount, answeredCount)
        sessionAttempts = restoredSession.snapshot.attempts.filter { attempt in
            restoredSession.snapshot.questionIDs.contains(attempt.questionID)
        }
        finishSummary = nil
        finished = questions.isEmpty
        remainingSeconds = restoredSession.snapshot.remainingSeconds
        resetQuestionState()

        if selectedMode == .mockExam, remainingSeconds > 0 {
            startTimer()
        }

        persistPracticeSession()
    }

    private func finalizeAttempt(
        question: Question,
        selectedAnswers: [String],
        isCorrect: Bool,
        subjectiveReviewStatus: SubjectiveReviewStatus?
    ) {
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

            sessionAttempts.removeAll { $0.questionID == question.id }
            sessionAttempts.append(
                PracticeAttemptRecord(
                    questionID: question.id,
                    isCorrect: isCorrect,
                    spentSeconds: spentSeconds
                )
            )

            if let subjectiveReviewStatus {
                currentSubjectiveReviewStatus = subjectiveReviewStatus
                saveSubjectiveAnnotation(
                    questionID: question.id,
                    reviewStatus: subjectiveReviewStatus,
                    note: subjectiveNoteDraft
                )
            }

            persistPracticeSession()
            notifyStudyDataChanged()
            prefetchDefaultAIInsight(for: question)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveSubjectiveAnnotation(
        questionID: Int64,
        reviewStatus: SubjectiveReviewStatus,
        note: String
    ) {
        do {
            let existingAnnotation = annotationsByQuestionID[questionID] ?? .empty(questionID: questionID)
            let annotation = QuestionAnnotation(
                questionID: questionID,
                note: note,
                tags: existingAnnotation.tags,
                subjectiveReviewStatus: reviewStatus,
                updatedAt: Date()
            )
            try questionRepository.saveQuestionAnnotation(annotation)
            annotationsByQuestionID[questionID] = annotation.isEmpty ? .empty(questionID: questionID) : annotation
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func finalizeSessionIfNeeded() {
        guard finishSummary == nil else { return }
        finishSummary = makeFinishSummary()
        practiceSessionStore.clear()
        notifyStudyDataChanged()
    }

    private func makeFinishSummary() -> PracticeFinishSummary {
        let attemptMap = Dictionary(uniqueKeysWithValues: sessionAttempts.map { ($0.questionID, $0) })
        let answeredQuestions = questions.filter { attemptMap[$0.id] != nil }
        let wrongQuestions = answeredQuestions.filter { !(attemptMap[$0.id]?.isCorrect ?? false) }
        let totalSpentSeconds = sessionAttempts.map(\.spentSeconds).reduce(0, +)
        let scoreEarned = answeredQuestions.reduce(into: 0.0) { partialResult, question in
            if attemptMap[question.id]?.isCorrect == true {
                partialResult += question.score
            }
        }
        let totalScore = questions.map(\.score).reduce(0, +)

        let wrongKnowledgeCounts = wrongQuestions.reduce(into: [String: Int]()) { counts, question in
            let key = question.knowledgePoints.first ?? question.category
            counts[key, default: 0] += 1
        }

        let wrongKnowledgePoints = wrongKnowledgeCounts
            .map { PracticeKnowledgeGap(name: $0.key, wrongCount: $0.value) }
            .sorted { lhs, rhs in
                if lhs.wrongCount == rhs.wrongCount {
                    return lhs.name.localizedCompare(rhs.name) == .orderedAscending
                }
                return lhs.wrongCount > rhs.wrongCount
            }

        let recommendation: String
        if let weakestPoint = wrongKnowledgePoints.first {
            recommendation = "优先围绕 \(weakestPoint.name) 再做一轮，先清掉最影响得分的知识点。"
        } else if selectedMode == .mockExam {
            recommendation = "整体完成得不错，下一步建议继续做一轮模考，保持考试节奏。"
        } else {
            recommendation = "建议切到错题重练，把这轮暴露的问题尽快闭环。"
        }

        return PracticeFinishSummary(
            totalQuestions: questions.count,
            answeredCount: answeredCount,
            correctCount: correctCount,
            scoreEarned: scoreEarned,
            totalScore: totalScore,
            totalSpentSeconds: totalSpentSeconds,
            remainingSeconds: remainingSeconds,
            wrongKnowledgePoints: wrongKnowledgePoints,
            recommendation: recommendation
        )
    }

    private func resetQuestionState() {
        aiInsightTask?.cancel()
        aiPrefetchTask?.cancel()
        latestAIInsightRequestID = UUID()
        questionStartDate = Date()
        selectedAnswers = []
        showAnalysis = false
        awaitingSubjectiveAssessment = false
        currentAnswerCorrect = nil
        aiInsight = nil
        activeAIStyle = nil
        aiErrorMessage = nil
        isAILoading = false
        loadCurrentQuestionAnnotation()
    }

    private func loadCurrentQuestionAnnotation() {
        guard let question = currentQuestion else {
            subjectiveNoteDraft = ""
            currentSubjectiveReviewStatus = nil
            return
        }

        let annotation = annotationsByQuestionID[question.id] ?? .empty(questionID: question.id)
        subjectiveNoteDraft = annotation.note
        currentSubjectiveReviewStatus = annotation.subjectiveReviewStatus
    }

    private func persistPracticeSession() {
        guard !questions.isEmpty, !finished else {
            practiceSessionStore.clear()
            return
        }

        practiceSessionStore.save(
            PracticeSessionSnapshot(
                modeRawValue: selectedMode.rawValue,
                category: selectedCategory,
                year: selectedYear,
                keyword: normalizedSearchText,
                selectedQuestionLimit: selectedQuestionLimit,
                questionIDs: questions.map(\.id),
                currentIndex: currentIndex,
                answeredCount: answeredCount,
                correctCount: correctCount,
                remainingSeconds: remainingSeconds,
                attempts: sessionAttempts,
                updatedAt: Date()
            )
        )
    }

    private func prefetchDefaultAIInsight(for question: Question) {
        aiPrefetchTask?.cancel()

        let style = defaultAIInsightStyle(for: question)
        let service = aiStudyService

        aiPrefetchTask = Task {
            _ = try? await service.generateInsight(for: question, style: style)
        }
    }

    private func defaultAIInsightStyle(for question: Question) -> AIInsightStyle {
        question.isObjective ? .explanation : .essayOutline
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
                    self.finalizeSessionIfNeeded()
                    return
                }
                self.remainingSeconds -= 1
                if self.remainingSeconds % 15 == 0 {
                    self.persistPracticeSession()
                }
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
