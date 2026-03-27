import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let database: SQLiteDatabase
    let questionRepository: QuestionRepositoryProtocol
    let progressRepository: ProgressRepositoryProtocol
    let analyticsRepository: AnalyticsRepositoryProtocol
    let aiStudyService: AIStudyServiceProtocol
    let focusSessionStore: FocusSessionStore
    @Published private(set) var isPrepared = false
    @Published private(set) var isPreparing = false
    @Published var preparationError: String?

    init(
        database: SQLiteDatabase,
        questionRepository: QuestionRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol,
        analyticsRepository: AnalyticsRepositoryProtocol,
        aiStudyService: AIStudyServiceProtocol,
        focusSessionStore: FocusSessionStore
    ) {
        self.database = database
        self.questionRepository = questionRepository
        self.progressRepository = progressRepository
        self.analyticsRepository = analyticsRepository
        self.aiStudyService = aiStudyService
        self.focusSessionStore = focusSessionStore
    }

    func prepareIfNeeded() {
        guard !isPrepared, !isPreparing else { return }

        isPreparing = true
        preparationError = nil

        let repository = questionRepository
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try repository.seedIfNeeded()

                Task { @MainActor [weak self] in
                    self?.isPreparing = false
                    self?.isPrepared = true
                }
            } catch {
                Task { @MainActor [weak self] in
                    self?.isPreparing = false
                    self?.preparationError = error.localizedDescription
                }
            }
        }
    }

    static func bootstrap() -> AppContainer {
        do {
            let database = try SQLiteDatabase(databaseName: "ruankao.sqlite")
            try DatabaseMigrator.migrate(database: database)

            let questionRepository = SQLiteQuestionRepository(database: database)
            let progressRepository = SQLiteProgressRepository(database: database)
            let analyticsRepository = SQLiteAnalyticsRepository(database: database)
            let aiStudyService = HybridAIStudyService(
                remote: RemoteAIStudyService(
                    configurationProvider: {
                        RemoteAIServiceConfiguration(
                            endpoint: AppConfiguration.aiServiceEndpoint,
                            bearerToken: AppConfiguration.aiServiceToken,
                            model: AppConfiguration.aiServiceModel,
                            protocolPreference: AppConfiguration.aiServiceProtocolPreference
                        )
                    }
                )
            )
            let focusSessionStore = FocusSessionStore()

            return AppContainer(
                database: database,
                questionRepository: questionRepository,
                progressRepository: progressRepository,
                analyticsRepository: analyticsRepository,
                aiStudyService: aiStudyService,
                focusSessionStore: focusSessionStore
            )
        } catch {
            fatalError("Failed to bootstrap application: \(error)")
        }
    }
}
