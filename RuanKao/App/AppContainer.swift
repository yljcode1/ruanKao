import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let database: SQLiteDatabase
    let questionRepository: QuestionRepositoryProtocol
    let progressRepository: ProgressRepositoryProtocol
    let analyticsRepository: AnalyticsRepositoryProtocol
    let aiStudyService: AIStudyServiceProtocol
    let focusSessionStore: FocusSessionStore

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

    static func bootstrap() -> AppContainer {
        do {
            let database = try SQLiteDatabase(databaseName: "ruankao.sqlite")
            try DatabaseMigrator.migrate(database: database)

            let questionRepository = SQLiteQuestionRepository(database: database)
            try questionRepository.seedIfNeeded()

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
