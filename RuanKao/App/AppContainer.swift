import Foundation

final class AppContainer: ObservableObject {
    let database: SQLiteDatabase
    let questionRepository: QuestionRepositoryProtocol
    let progressRepository: ProgressRepositoryProtocol
    let analyticsRepository: AnalyticsRepositoryProtocol
    let aiStudyService: AIStudyServiceProtocol

    init(
        database: SQLiteDatabase,
        questionRepository: QuestionRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol,
        analyticsRepository: AnalyticsRepositoryProtocol,
        aiStudyService: AIStudyServiceProtocol
    ) {
        self.database = database
        self.questionRepository = questionRepository
        self.progressRepository = progressRepository
        self.analyticsRepository = analyticsRepository
        self.aiStudyService = aiStudyService
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

            return AppContainer(
                database: database,
                questionRepository: questionRepository,
                progressRepository: progressRepository,
                analyticsRepository: analyticsRepository,
                aiStudyService: aiStudyService
            )
        } catch {
            fatalError("Failed to bootstrap application: \(error)")
        }
    }
}
