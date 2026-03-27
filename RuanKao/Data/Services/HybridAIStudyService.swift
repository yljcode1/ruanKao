import Foundation

private actor AIInsightCacheStore {
    private struct PersistedEntry: Codable {
        let questionID: Int64
        let style: AIInsightStyle
        let insight: AIStudyInsight
        let updatedAt: Date
    }

    struct Key: Hashable {
        let questionID: Int64
        let style: AIInsightStyle
    }

    private var values: [Key: AIStudyInsight] = [:]
    private var inFlightTasks: [Key: Task<AIStudyInsight, Error>] = [:]
    private var hasLoadedPersistedValues = false
    private let maxPersistedEntryCount = 240
    private let fileURL: URL = {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return baseURL.appendingPathComponent("ai_insight_cache_v1.json")
    }()

    func cachedValue(for key: Key) -> AIStudyInsight? {
        ensureLoadedIfNeeded()
        return values[key]
    }

    func inFlightTask(for key: Key) -> Task<AIStudyInsight, Error>? {
        inFlightTasks[key]
    }

    func store(_ value: AIStudyInsight, for key: Key) {
        ensureLoadedIfNeeded()
        values[key] = value
        persistValues()
    }

    func setInFlightTask(_ task: Task<AIStudyInsight, Error>, for key: Key) {
        inFlightTasks[key] = task
    }

    func clearInFlightTask(for key: Key) {
        inFlightTasks[key] = nil
    }

    private func ensureLoadedIfNeeded() {
        guard !hasLoadedPersistedValues else { return }
        hasLoadedPersistedValues = true

        guard let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([PersistedEntry].self, from: data)
        else {
            return
        }

        values = entries.reduce(into: [:]) { partialResult, entry in
            partialResult[Key(questionID: entry.questionID, style: entry.style)] = entry.insight
        }
    }

    private func persistValues() {
        let entries = values.map { item in
            PersistedEntry(
                questionID: item.key.questionID,
                style: item.key.style,
                insight: item.value,
                updatedAt: Date()
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
        .prefix(maxPersistedEntryCount)

        guard let data = try? JSONEncoder().encode(Array(entries)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

final class HybridAIStudyService: AIStudyServiceProtocol, @unchecked Sendable {
    private let remote: RemoteAIStudyService
    private let fallback: MockAIStudyService
    private let cacheStore = AIInsightCacheStore()

    init(remote: RemoteAIStudyService, fallback: MockAIStudyService = MockAIStudyService()) {
        self.remote = remote
        self.fallback = fallback
    }

    func generateInsight(for question: Question, style: AIInsightStyle) async throws -> AIStudyInsight {
        let key = AIInsightCacheStore.Key(questionID: question.id, style: style)

        if let cached = await cacheStore.cachedValue(for: key) {
            return cached
        }

        if let inFlightTask = await cacheStore.inFlightTask(for: key) {
            return try await inFlightTask.value
        }

        let remoteService = remote
        let fallbackService = fallback
        let task = Task<AIStudyInsight, Error> {
            do {
                return try await remoteService.generateInsight(for: question, style: style)
            } catch {
                return try await fallbackService.generateInsight(for: question, style: style)
            }
        }

        await cacheStore.setInFlightTask(task, for: key)

        do {
            let insight = try await task.value
            await cacheStore.store(insight, for: key)
            await cacheStore.clearInFlightTask(for: key)
            return insight
        } catch {
            await cacheStore.clearInFlightTask(for: key)
            throw error
        }
    }
}
