import Combine
import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let database: SQLiteDatabase
    let questionRepository: QuestionRepositoryProtocol
    let progressRepository: ProgressRepositoryProtocol
    let analyticsRepository: AnalyticsRepositoryProtocol
    let aiStudyService: AIStudyServiceProtocol
    let focusSessionStore: FocusSessionStore
    let recentActivityStore: RecentActivityStore
    @Published private(set) var isPrepared = false
    @Published private(set) var isPreparing = false
    @Published var preparationError: String?

    init(
        database: SQLiteDatabase,
        questionRepository: QuestionRepositoryProtocol,
        progressRepository: ProgressRepositoryProtocol,
        analyticsRepository: AnalyticsRepositoryProtocol,
        aiStudyService: AIStudyServiceProtocol,
        focusSessionStore: FocusSessionStore,
        recentActivityStore: RecentActivityStore
    ) {
        self.database = database
        self.questionRepository = questionRepository
        self.progressRepository = progressRepository
        self.analyticsRepository = analyticsRepository
        self.aiStudyService = aiStudyService
        self.focusSessionStore = focusSessionStore
        self.recentActivityStore = recentActivityStore
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
            let recentActivityStore = RecentActivityStore()

            return AppContainer(
                database: database,
                questionRepository: questionRepository,
                progressRepository: progressRepository,
                analyticsRepository: analyticsRepository,
                aiStudyService: aiStudyService,
                focusSessionStore: focusSessionStore,
                recentActivityStore: recentActivityStore
            )
        } catch {
            fatalError("Failed to bootstrap application: \(error)")
        }
    }
}

@MainActor
final class RecentActivityStore: ObservableObject {
    @Published private(set) var recentSearches: [String]
    @Published private(set) var recentSessions: [RecentPracticeEntry]

    private let defaults: UserDefaults
    private let searchKey = "recent_searches_v1"
    private let sessionKey = "recent_practice_sessions_v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxSearchCount = 8
    private let maxSessionCount = 6

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recentSearches = defaults.stringArray(forKey: searchKey) ?? []

        if let data = defaults.data(forKey: sessionKey),
           let sessions = try? decoder.decode([RecentPracticeEntry].self, from: data) {
            recentSessions = sessions.sorted { $0.updatedAt > $1.updatedAt }
        } else {
            recentSessions = []
        }
    }

    func recordSearch(_ rawKeyword: String?) {
        guard let keyword = normalized(rawKeyword) else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(keyword) == .orderedSame }
        recentSearches.insert(keyword, at: 0)
        recentSearches = Array(recentSearches.prefix(maxSearchCount))
        defaults.set(recentSearches, forKey: searchKey)
    }

    func clearSearches() {
        recentSearches = []
        defaults.removeObject(forKey: searchKey)
    }

    func recordPractice(mode: PracticeMode, category: String?, year: Int?, keyword: String?) {
        let entry = RecentPracticeEntry(
            modeRawValue: mode.rawValue,
            category: normalized(category),
            year: year,
            keyword: normalized(keyword),
            updatedAt: Date()
        )

        recentSessions.removeAll { $0.id == entry.id }
        recentSessions.insert(entry, at: 0)
        recentSessions = Array(recentSessions.prefix(maxSessionCount))

        if let data = try? encoder.encode(recentSessions) {
            defaults.set(data, forKey: sessionKey)
        }

        if let keyword = entry.keyword {
            recordSearch(keyword)
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct RecentPracticeEntry: Codable, Hashable, Identifiable {
    let modeRawValue: String
    let category: String?
    let year: Int?
    let keyword: String?
    let updatedAt: Date

    var id: String {
        [modeRawValue, category ?? "", year.map(String.init) ?? "", keyword?.lowercased() ?? ""]
            .joined(separator: "|")
    }

    var mode: PracticeMode {
        PracticeMode(rawValue: modeRawValue) ?? .sequential
    }

    var title: String {
        mode.title
    }

    var subtitle: String {
        var parts: [String] = []

        if let year {
            parts.append("\(year)")
        }

        if let category {
            parts.append(category)
        }

        if let keyword {
            parts.append("搜：\(keyword)")
        }

        return parts.isEmpty ? "无筛选条件，直接继续练" : parts.joined(separator: " · ")
    }
}
