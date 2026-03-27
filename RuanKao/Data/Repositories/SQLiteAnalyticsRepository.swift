import Foundation
import SQLite3

final class SQLiteAnalyticsRepository: AnalyticsRepositoryProtocol, @unchecked Sendable {
    private let database: SQLiteDatabase
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func dashboardSnapshot() throws -> DashboardSnapshot {
        let streak = try streakSummary()
        return DashboardSnapshot(
            totalQuestions: try scalarInt("SELECT COUNT(*) FROM questions;"),
            answeredQuestions: try scalarInt("SELECT COUNT(DISTINCT question_id) FROM attempt_records;"),
            todayPracticeCount: try scalarInt(
                """
                SELECT COUNT(*)
                FROM attempt_records
                WHERE date(attempted_at, 'unixepoch', 'localtime') = date('now', 'localtime');
                """
            ),
            overallAccuracy: try scalarDouble("SELECT COALESCE(AVG(is_correct), 0) FROM attempt_records;"),
            currentStreak: streak.current,
            longestStreak: streak.longest,
            todayCheckedIn: streak.todayCheckedIn,
            weakKnowledgePoints: try weakKnowledgePoints(limit: 5),
            recentTrend: try recentTrend(days: 7)
        )
    }

    func weakKnowledgePoints(limit: Int) throws -> [KnowledgeStat] {
        try database.read { db in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT qkp.knowledge_point,
                       COUNT(ar.id) AS practiced_count,
                       COALESCE(AVG(ar.is_correct), 0) AS accuracy
                FROM question_knowledge_points qkp
                LEFT JOIN attempt_records ar ON ar.question_id = qkp.question_id
                GROUP BY qkp.knowledge_point
                HAVING practiced_count > 0
                ORDER BY accuracy ASC, practiced_count DESC
                LIMIT ?;
                """
            )
            defer { sqlite3_finalize(statement) }
            try bind([.int(Int64(limit))], to: statement)

            var stats: [KnowledgeStat] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                stats.append(
                    KnowledgeStat(
                        name: columnText(statement, index: 0),
                        practicedCount: Int(sqlite3_column_int(statement, 1)),
                        accuracy: sqlite3_column_double(statement, 2)
                    )
                )
            }

            return stats
        }
    }

    func recentTrend(days: Int) throws -> [DailyTrend] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) else {
            return []
        }

        let startTimestamp = startDate.timeIntervalSince1970

        let rows = try database.read { db -> [String: DailyTrend] in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT date(attempted_at, 'unixepoch', 'localtime') AS practice_day,
                       COUNT(*) AS practiced_count,
                       COALESCE(AVG(is_correct), 0) AS accuracy
                FROM attempt_records
                WHERE attempted_at >= ?
                GROUP BY practice_day
                ORDER BY practice_day ASC;
                """
            )
            defer { sqlite3_finalize(statement) }
            try bind([.double(startTimestamp)], to: statement)

            var mapping: [String: DailyTrend] = [:]

            while sqlite3_step(statement) == SQLITE_ROW {
                let dayString = columnText(statement, index: 0)
                guard let date = dayFormatter.date(from: dayString) else { continue }

                mapping[dayString] = DailyTrend(
                    date: date,
                    practicedCount: Int(sqlite3_column_int(statement, 1)),
                    accuracy: sqlite3_column_double(statement, 2)
                )
            }

            return mapping
        }

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else {
                return nil
            }

            let key = dayFormatter.string(from: date)
            return rows[key] ?? DailyTrend(date: date, practicedCount: 0, accuracy: 0)
        }
    }

    private func scalarInt(_ sql: String) throws -> Int {
        try database.read { db in
            let statement = try prepareStatement(database: db, sql: sql)
            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return Int(sqlite3_column_int(statement, 0))
        }
    }

    private func scalarDouble(_ sql: String) throws -> Double {
        try database.read { db in
            let statement = try prepareStatement(database: db, sql: sql)
            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return sqlite3_column_double(statement, 0)
        }
    }

    private func streakSummary() throws -> (current: Int, longest: Int, todayCheckedIn: Bool) {
        let dayStrings = try database.read { db -> [String] in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT DISTINCT date(attempted_at, 'unixepoch', 'localtime') AS practice_day
                FROM attempt_records
                ORDER BY practice_day DESC;
                """
            )
            defer { sqlite3_finalize(statement) }

            var values: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                values.append(columnText(statement, index: 0))
            }
            return values
        }

        let dates = dayStrings.compactMap { dayFormatter.date(from: $0) }
        guard !dates.isEmpty else {
            return (0, 0, false)
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let normalized = Array(Set(dates.map { calendar.startOfDay(for: $0) })).sorted(by: >)
        let todayCheckedIn = normalized.contains(today)

        var current = 0
        var cursor = todayCheckedIn ? today : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        for date in normalized {
            if calendar.isDate(date, inSameDayAs: cursor) {
                current += 1
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            } else if date < cursor {
                break
            }
        }

        var longest = 1
        var running = 1
        for index in 1..<normalized.count {
            let previous = normalized[index - 1]
            let currentDate = normalized[index]
            if let diff = calendar.dateComponents([.day], from: currentDate, to: previous).day, diff == 1 {
                running += 1
                longest = max(longest, running)
            } else {
                running = 1
            }
        }

        return (current, longest, todayCheckedIn)
    }
}
