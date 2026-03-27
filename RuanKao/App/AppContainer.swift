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
        recentActivityStore: RecentActivityStore,
        isPrepared: Bool = false
    ) {
        self.database = database
        self.questionRepository = questionRepository
        self.progressRepository = progressRepository
        self.analyticsRepository = analyticsRepository
        self.aiStudyService = aiStudyService
        self.focusSessionStore = focusSessionStore
        self.recentActivityStore = recentActivityStore
        self.isPrepared = isPrepared
    }

    func prepareIfNeeded() {
        guard !isPrepared, !isPreparing else { return }

        isPreparing = true
        preparationError = nil
        runQuestionBankPreparation(qos: .userInitiated, surfacesErrorsInUI: true)
    }

    private func runQuestionBankPreparation(
        qos: DispatchQoS.QoSClass,
        surfacesErrorsInUI: Bool
    ) {
        let repository = questionRepository
        let work = { [weak self] in
            do {
                try repository.seedIfNeeded()

                Task { @MainActor [weak self] in
                    self?.isPrepared = true
                    if surfacesErrorsInUI {
                        self?.isPreparing = false
                    }
                }
            } catch {
                Task { @MainActor [weak self] in
                    if surfacesErrorsInUI {
                        self?.isPreparing = false
                        self?.preparationError = error.localizedDescription
                    } else {
                        print("Failed to synchronize bundled question bank: \(error)")
                    }
                }
            }
        }

        DispatchQueue.global(qos: qos).async(execute: work)
    }

    static func bootstrap() -> AppContainer {
        do {
            let databaseName = "ruankao.sqlite"
            do {
                try QuestionSeedLoader.installBundledDatabaseIfNeeded(databaseName: databaseName)
            } catch {
                print("Failed to install bundled seed database: \(error)")
            }

            let database = try SQLiteDatabase(databaseName: databaseName)
            try DatabaseMigrator.migrate(database: database)

            let questionRepository = SQLiteQuestionRepository(database: database)
            let progressRepository = SQLiteProgressRepository(database: database)
            let analyticsRepository = SQLiteAnalyticsRepository(database: database)
            do {
                try questionRepository.seedIfNeeded()
            } catch {
                print("Failed to synchronize bundled question bank during bootstrap: \(error)")
            }
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
            let hasQuestionBank = (try? questionRepository.hasQuestionBank()) ?? false

            let container = AppContainer(
                database: database,
                questionRepository: questionRepository,
                progressRepository: progressRepository,
                analyticsRepository: analyticsRepository,
                aiStudyService: aiStudyService,
                focusSessionStore: focusSessionStore,
                recentActivityStore: recentActivityStore,
                isPrepared: hasQuestionBank
            )
            return container
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
            recentSessions = Self.sortedSessions(sessions)
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
        let existingPinned = recentSessions.first {
            $0.id == RecentPracticeEntry.makeID(
                modeRawValue: mode.rawValue,
                category: normalized(category),
                year: year,
                keyword: normalized(keyword)
            )
        }?.isPinned ?? false
        let entry = RecentPracticeEntry(
            modeRawValue: mode.rawValue,
            category: normalized(category),
            year: year,
            keyword: normalized(keyword),
            updatedAt: Date(),
            isPinned: existingPinned
        )

        recentSessions.removeAll { $0.id == entry.id }
        recentSessions.append(entry)
        persistSessions()

        if let keyword = entry.keyword {
            recordSearch(keyword)
        }
    }

    func togglePin(entryID: String) {
        guard let index = recentSessions.firstIndex(where: { $0.id == entryID }) else { return }
        recentSessions[index] = recentSessions[index].settingPinned(!recentSessions[index].isPinned)
        persistSessions()
    }

    func removePractice(entryID: String) {
        recentSessions.removeAll { $0.id == entryID }
        persistSessions()
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persistSessions() {
        recentSessions = Array(Self.sortedSessions(recentSessions).prefix(maxSessionCount))

        guard !recentSessions.isEmpty else {
            defaults.removeObject(forKey: sessionKey)
            return
        }

        if let data = try? encoder.encode(recentSessions) {
            defaults.set(data, forKey: sessionKey)
        }
    }

    private static func sortedSessions(_ sessions: [RecentPracticeEntry]) -> [RecentPracticeEntry] {
        sessions.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}

struct RecentPracticeEntry: Codable, Hashable, Identifiable {
    let modeRawValue: String
    let category: String?
    let year: Int?
    let keyword: String?
    let updatedAt: Date
    let isPinned: Bool

    private enum CodingKeys: String, CodingKey {
        case modeRawValue
        case category
        case year
        case keyword
        case updatedAt
        case isPinned
    }

    init(
        modeRawValue: String,
        category: String?,
        year: Int?,
        keyword: String?,
        updatedAt: Date,
        isPinned: Bool = false
    ) {
        self.modeRawValue = modeRawValue
        self.category = category
        self.year = year
        self.keyword = keyword
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        modeRawValue = try container.decode(String.self, forKey: .modeRawValue)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        keyword = try container.decodeIfPresent(String.self, forKey: .keyword)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
    }

    var id: String {
        Self.makeID(modeRawValue: modeRawValue, category: category, year: year, keyword: keyword)
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

    func settingPinned(_ isPinned: Bool) -> RecentPracticeEntry {
        RecentPracticeEntry(
            modeRawValue: modeRawValue,
            category: category,
            year: year,
            keyword: keyword,
            updatedAt: updatedAt,
            isPinned: isPinned
        )
    }

    static func makeID(modeRawValue: String, category: String?, year: Int?, keyword: String?) -> String {
        [modeRawValue, category ?? "", year.map(String.init) ?? "", keyword?.lowercased() ?? ""]
            .joined(separator: "|")
    }
}
