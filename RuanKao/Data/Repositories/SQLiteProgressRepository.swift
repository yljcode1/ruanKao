import Foundation
import SQLite3

final class SQLiteProgressRepository: ProgressRepositoryProtocol {
    private let database: SQLiteDatabase
    private let encoder = JSONEncoder()

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func recordAttempt(
        question: Question,
        selectedAnswers: [String],
        isCorrect: Bool,
        spentSeconds: Int
    ) throws {
        let selectedData = try encoder.encode(selectedAnswers)
        let selectedText = String(decoding: selectedData, as: UTF8.self)
        let now = Date().timeIntervalSince1970

        try database.write { db in
            let attemptStatement = try prepareStatement(
                database: db,
                sql: """
                INSERT INTO attempt_records
                (question_id, selected_answers, is_correct, spent_seconds, attempted_at)
                VALUES (?, ?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(attemptStatement) }

            try bind(
                [
                    .int(question.id),
                    .text(selectedText),
                    .bool(isCorrect),
                    .int(Int64(spentSeconds)),
                    .double(now)
                ],
                to: attemptStatement
            )

            guard sqlite3_step(attemptStatement) == SQLITE_DONE else {
                throw SQLiteError.stepFailed(database.lastErrorMessage(db))
            }

            guard !isCorrect else { return }

            let wrongStatement = try prepareStatement(
                database: db,
                sql: """
                INSERT INTO wrong_questions (question_id, wrong_count, last_wrong_at, is_mastered)
                VALUES (?, 1, ?, 0)
                ON CONFLICT(question_id) DO UPDATE SET
                wrong_count = wrong_count + 1,
                last_wrong_at = excluded.last_wrong_at,
                is_mastered = 0;
                """
            )
            defer { sqlite3_finalize(wrongStatement) }

            try bind([.int(question.id), .double(now)], to: wrongStatement)

            guard sqlite3_step(wrongStatement) == SQLITE_DONE else {
                throw SQLiteError.stepFailed(database.lastErrorMessage(db))
            }
        }
    }
}
