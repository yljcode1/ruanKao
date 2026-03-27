import Foundation
import SQLite3

final class SQLiteQuestionRepository: QuestionRepositoryProtocol {
    private struct QuestionRow {
        let id: Int64
        let year: Int
        let stage: String
        let type: QuestionType
        let category: String
        let stem: String
        let correctAnswers: [String]
        let analysis: String
        let score: Double
        let estimatedMinutes: Int
    }

    private struct WrongRow {
        let questionID: Int64
        let wrongCount: Int
        let lastWrongAt: Date
        let isMastered: Bool
    }

    private let database: SQLiteDatabase
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func seedIfNeeded() throws {
        let questions = QuestionSeedLoader.load()
        guard !questions.isEmpty else { return }

        for question in questions {
            try upsert(question: question)
        }
    }

    func loadPracticeQuestions(mode: PracticeMode, limit: Int, category: String?, year: Int?, keyword: String?) throws -> [Question] {
        var sql = """
        SELECT id, year, stage, type, category, stem, correct_answers, analysis, score, estimated_minutes
        FROM questions
        """

        var bindings: [SQLiteBindingValue] = []
        var clauses: [String] = []

        if let category, !category.isEmpty {
            clauses.append("category = ?")
            bindings.append(.text(category))
        }

        if let year {
            clauses.append("year = ?")
            bindings.append(.int(Int64(year)))
        }

        if let keyword, !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let pattern = "%\(keyword.trimmingCharacters(in: .whitespacesAndNewlines))%"
            clauses.append(
                """
                (
                    questions.stem LIKE ?
                    OR questions.category LIKE ?
                    OR EXISTS (
                        SELECT 1 FROM question_knowledge_points qkp
                        WHERE qkp.question_id = questions.id
                          AND qkp.knowledge_point LIKE ?
                    )
                )
                """
            )
            bindings.append(.text(pattern))
            bindings.append(.text(pattern))
            bindings.append(.text(pattern))
        }

        if mode == .wrongOnly {
            sql += " INNER JOIN wrong_questions ON wrong_questions.question_id = questions.id "
            clauses.append("wrong_questions.is_mastered = 0")
        }

        if !clauses.isEmpty {
            sql += " WHERE " + clauses.joined(separator: " AND ")
        }

        switch mode {
        case .sequential:
            sql += " ORDER BY year DESC, id ASC "
        case .random, .mockExam, .wrongOnly:
            sql += " ORDER BY RANDOM() "
        }

        sql += " LIMIT ?;"
        bindings.append(.int(Int64(limit)))

        let rows = try fetchQuestionRows(sql: sql, bindings: bindings)
        return try rows.map(makeQuestion)
    }

    func fetchCategories() throws -> [String] {
        try database.read { db in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT DISTINCT category
                FROM questions
                ORDER BY category ASC;
                """
            )
            defer { sqlite3_finalize(statement) }

            var categories: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                categories.append(columnText(statement, index: 0))
            }
            return categories
        }
    }

    func fetchAvailableYears() throws -> [Int] {
        try database.read { db in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT DISTINCT year
                FROM questions
                ORDER BY year DESC;
                """
            )
            defer { sqlite3_finalize(statement) }

            var years: [Int] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                years.append(Int(sqlite3_column_int(statement, 0)))
            }
            return years
        }
    }

    func fetchTopicSummaries(limit: Int?) throws -> [TopicSummary] {
        var sql = """
        SELECT
            category,
            COUNT(*) AS question_count,
            MAX(year) AS latest_year,
            SUM(CASE WHEN type = 'singleChoice' THEN 1 ELSE 0 END) AS objective_count,
            SUM(CASE WHEN type != 'singleChoice' THEN 1 ELSE 0 END) AS subjective_count
        FROM questions
        GROUP BY category
        ORDER BY question_count DESC, latest_year DESC, category ASC
        """

        var bindings: [SQLiteBindingValue] = []
        if let limit {
            sql += " LIMIT ?"
            bindings.append(.int(Int64(limit)))
        }
        sql += ";"

        return try database.read { db in
            let statement = try prepareStatement(database: db, sql: sql)
            defer { sqlite3_finalize(statement) }
            try bind(bindings, to: statement)

            var summaries: [TopicSummary] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                summaries.append(
                    TopicSummary(
                        category: columnText(statement, index: 0),
                        questionCount: Int(sqlite3_column_int(statement, 1)),
                        latestYear: Int(sqlite3_column_int(statement, 2)),
                        objectiveCount: Int(sqlite3_column_int(statement, 3)),
                        subjectiveCount: Int(sqlite3_column_int(statement, 4))
                    )
                )
            }

            return summaries
        }
    }

    func fetchFavoriteQuestions() throws -> [Question] {
        let sql = """
        SELECT questions.id, questions.year, questions.stage, questions.type, questions.category, questions.stem, questions.correct_answers, questions.analysis, questions.score, questions.estimated_minutes
        FROM questions
        INNER JOIN favorite_questions ON favorite_questions.question_id = questions.id
        ORDER BY favorite_questions.created_at DESC;
        """

        let rows = try fetchQuestionRows(sql: sql, bindings: [])
        return try rows.map(makeQuestion)
    }

    func fetchFavoriteQuestionIDs() throws -> Set<Int64> {
        try database.read { db in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT question_id
                FROM favorite_questions;
                """
            )
            defer { sqlite3_finalize(statement) }

            var ids = Set<Int64>()
            while sqlite3_step(statement) == SQLITE_ROW {
                ids.insert(sqlite3_column_int64(statement, 0))
            }
            return ids
        }
    }

    func setFavorite(questionID: Int64, isFavorite: Bool) throws {
        try database.write { db in
            if isFavorite {
                let statement = try prepareStatement(
                    database: db,
                    sql: """
                    INSERT INTO favorite_questions (question_id, created_at)
                    VALUES (?, ?)
                    ON CONFLICT(question_id) DO UPDATE SET created_at = excluded.created_at;
                    """
                )
                defer { sqlite3_finalize(statement) }

                try bind([.int(questionID), .double(Date().timeIntervalSince1970)], to: statement)
                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw SQLiteError.stepFailed(database.lastErrorMessage(db))
                }
            } else {
                let statement = try prepareStatement(
                    database: db,
                    sql: """
                    DELETE FROM favorite_questions
                    WHERE question_id = ?;
                    """
                )
                defer { sqlite3_finalize(statement) }

                try bind([.int(questionID)], to: statement)
                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw SQLiteError.stepFailed(database.lastErrorMessage(db))
                }
            }
        }
    }

    func fetchWrongQuestions(includeMastered: Bool) throws -> [WrongQuestionItem] {
        var sql = """
        SELECT question_id, wrong_count, last_wrong_at, is_mastered
        FROM wrong_questions
        """

        if !includeMastered {
            sql += " WHERE is_mastered = 0 "
        }

        sql += " ORDER BY is_mastered ASC, last_wrong_at DESC;"

        let wrongRows = try database.read { db -> [WrongRow] in
            let statement = try prepareStatement(database: db, sql: sql)
            defer { sqlite3_finalize(statement) }

            var rows: [WrongRow] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                rows.append(
                    WrongRow(
                        questionID: sqlite3_column_int64(statement, 0),
                        wrongCount: Int(sqlite3_column_int(statement, 1)),
                        lastWrongAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                        isMastered: columnBool(statement, index: 3)
                    )
                )
            }

            return rows
        }

        return try wrongRows.compactMap { row in
            guard let question = try fetchQuestion(id: row.questionID) else {
                return nil
            }

            return WrongQuestionItem(
                id: row.questionID,
                question: question,
                wrongCount: row.wrongCount,
                lastWrongAt: row.lastWrongAt,
                isMastered: row.isMastered
            )
        }
    }

    func markWrongQuestionMastered(questionID: Int64, isMastered: Bool) throws {
        try database.write { db in
            let statement = try prepareStatement(
                database: db,
                sql: "UPDATE wrong_questions SET is_mastered = ? WHERE question_id = ?;"
            )
            defer { sqlite3_finalize(statement) }

            try bind([.bool(isMastered), .int(questionID)], to: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw SQLiteError.stepFailed(database.lastErrorMessage(db))
            }
        }
    }

    private func upsert(question: Question) throws {
        let answersData = try encoder.encode(question.correctAnswers)
        let answersText = String(decoding: answersData, as: UTF8.self)

        try database.write { db in
            let questionStatement = try prepareStatement(
                database: db,
                sql: """
                INSERT INTO questions
                (id, year, stage, type, category, stem, correct_answers, analysis, score, estimated_minutes)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(id) DO UPDATE SET
                    year = excluded.year,
                    stage = excluded.stage,
                    type = excluded.type,
                    category = excluded.category,
                    stem = excluded.stem,
                    correct_answers = excluded.correct_answers,
                    analysis = excluded.analysis,
                    score = excluded.score,
                    estimated_minutes = excluded.estimated_minutes;
                """
            )
            defer { sqlite3_finalize(questionStatement) }

            try bind(
                [
                    .int(question.id),
                    .int(Int64(question.year)),
                    .text(question.stage),
                    .text(question.type.rawValue),
                    .text(question.category),
                    .text(question.stem),
                    .text(answersText),
                    .text(question.analysis),
                    .double(question.score),
                    .int(Int64(question.estimatedMinutes))
                ],
                to: questionStatement
            )

            guard sqlite3_step(questionStatement) == SQLITE_DONE else {
                throw SQLiteError.stepFailed(database.lastErrorMessage(db))
            }

            let deleteOptionsStatement = try prepareStatement(
                database: db,
                sql: """
                DELETE FROM question_options
                WHERE question_id = ?;
                """
            )
            defer { sqlite3_finalize(deleteOptionsStatement) }
            try bind([.int(question.id)], to: deleteOptionsStatement)

            guard sqlite3_step(deleteOptionsStatement) == SQLITE_DONE else {
                throw SQLiteError.stepFailed(database.lastErrorMessage(db))
            }

            for (index, option) in question.options.enumerated() {
                let optionStatement = try prepareStatement(
                    database: db,
                    sql: """
                    INSERT INTO question_options (question_id, label, content, display_order)
                    VALUES (?, ?, ?, ?);
                    """
                )
                defer { sqlite3_finalize(optionStatement) }

                try bind(
                    [
                        .int(question.id),
                        .text(option.label),
                        .text(option.content),
                        .int(Int64(index))
                    ],
                    to: optionStatement
                )

                guard sqlite3_step(optionStatement) == SQLITE_DONE else {
                    throw SQLiteError.stepFailed(database.lastErrorMessage(db))
                }
            }

            let deleteKnowledgePointsStatement = try prepareStatement(
                database: db,
                sql: """
                DELETE FROM question_knowledge_points
                WHERE question_id = ?;
                """
            )
            defer { sqlite3_finalize(deleteKnowledgePointsStatement) }
            try bind([.int(question.id)], to: deleteKnowledgePointsStatement)

            guard sqlite3_step(deleteKnowledgePointsStatement) == SQLITE_DONE else {
                throw SQLiteError.stepFailed(database.lastErrorMessage(db))
            }

            for knowledgePoint in question.knowledgePoints {
                let knowledgeStatement = try prepareStatement(
                    database: db,
                    sql: """
                    INSERT INTO question_knowledge_points (question_id, knowledge_point)
                    VALUES (?, ?);
                    """
                )
                defer { sqlite3_finalize(knowledgeStatement) }

                try bind([.int(question.id), .text(knowledgePoint)], to: knowledgeStatement)

                guard sqlite3_step(knowledgeStatement) == SQLITE_DONE else {
                    throw SQLiteError.stepFailed(database.lastErrorMessage(db))
                }
            }
        }
    }

    private func fetchQuestion(id: Int64) throws -> Question? {
        let sql = """
        SELECT id, year, stage, type, category, stem, correct_answers, analysis, score, estimated_minutes
        FROM questions
        WHERE id = ?
        LIMIT 1;
        """

        let rows = try fetchQuestionRows(sql: sql, bindings: [.int(id)])
        return try rows.first.map(makeQuestion)
    }

    private func fetchQuestionRows(sql: String, bindings: [SQLiteBindingValue]) throws -> [QuestionRow] {
        try database.read { db in
            let statement = try prepareStatement(database: db, sql: sql)
            defer { sqlite3_finalize(statement) }
            try bind(bindings, to: statement)

            var rows: [QuestionRow] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                let answersText = columnText(statement, index: 6)
                let answersData = Data(answersText.utf8)
                let answers = (try? decoder.decode([String].self, from: answersData)) ?? []
                let type = QuestionType(rawValue: columnText(statement, index: 3)) ?? .singleChoice

                rows.append(
                    QuestionRow(
                        id: sqlite3_column_int64(statement, 0),
                        year: Int(sqlite3_column_int(statement, 1)),
                        stage: columnText(statement, index: 2),
                        type: type,
                        category: columnText(statement, index: 4),
                        stem: columnText(statement, index: 5),
                        correctAnswers: answers,
                        analysis: columnText(statement, index: 7),
                        score: sqlite3_column_double(statement, 8),
                        estimatedMinutes: Int(sqlite3_column_int(statement, 9))
                    )
                )
            }

            return rows
        }
    }

    private func fetchOptions(questionID: Int64) throws -> [QuestionOption] {
        try database.read { db in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT label, content
                FROM question_options
                WHERE question_id = ?
                ORDER BY display_order ASC;
                """
            )
            defer { sqlite3_finalize(statement) }
            try bind([.int(questionID)], to: statement)

            var options: [QuestionOption] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                options.append(
                    QuestionOption(
                        label: columnText(statement, index: 0),
                        content: columnText(statement, index: 1)
                    )
                )
            }

            return options
        }
    }

    private func fetchKnowledgePoints(questionID: Int64) throws -> [String] {
        try database.read { db in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT knowledge_point
                FROM question_knowledge_points
                WHERE question_id = ?
                ORDER BY knowledge_point ASC;
                """
            )
            defer { sqlite3_finalize(statement) }
            try bind([.int(questionID)], to: statement)

            var knowledgePoints: [String] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                knowledgePoints.append(columnText(statement, index: 0))
            }

            return knowledgePoints
        }
    }

    private func makeQuestion(row: QuestionRow) throws -> Question {
        Question(
            id: row.id,
            year: row.year,
            stage: row.stage,
            type: row.type,
            category: row.category,
            knowledgePoints: try fetchKnowledgePoints(questionID: row.id),
            stem: row.stem,
            options: try fetchOptions(questionID: row.id),
            correctAnswers: row.correctAnswers,
            analysis: row.analysis,
            score: row.score,
            estimatedMinutes: row.estimatedMinutes
        )
    }
}
