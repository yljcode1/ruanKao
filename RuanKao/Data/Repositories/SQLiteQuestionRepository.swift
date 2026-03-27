import Foundation
import SQLite3

final class SQLiteQuestionRepository: QuestionRepositoryProtocol, @unchecked Sendable {
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

    private struct QuestionQuery {
        var fromClause = "FROM questions"
        var clauses: [String] = []
        var bindings: [SQLiteBindingValue] = []

        var whereClause: String {
            clauses.isEmpty ? "" : " WHERE " + clauses.joined(separator: " AND ")
        }
    }

    private enum MetadataKey {
        static let questionSeedManifest = "question_seed_manifest"
        static let questionSearchManifest = "question_search_manifest"
    }

    private let database: SQLiteDatabase
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func seedIfNeeded() throws {
        let currentManifest = QuestionSeedLoader.currentManifest()
        let searchManifest = searchManifest(for: currentManifest)
        let storedManifest = try metadataValue(for: MetadataKey.questionSeedManifest)
        let storedSearchManifest = try metadataValue(for: MetadataKey.questionSearchManifest)
        let searchIndexSupported = try hasSearchIndex()
        let searchIndexRows = searchIndexSupported ? try searchIndexCount() : 0

        if storedManifest == currentManifest, try questionCount() > 0 {
            if searchIndexSupported,
               (storedSearchManifest != searchManifest || searchIndexRows == 0) {
                try rebuildSearchIndex(searchManifest: searchManifest)
            }
            return
        }

        let seedBundle = QuestionSeedLoader.loadSeedBundle()
        guard !seedBundle.questions.isEmpty else { return }

        try bulkUpsert(
            questions: seedBundle.questions,
            manifest: seedBundle.manifest,
            searchManifest: searchManifest,
            searchIndexSupported: searchIndexSupported
        )
    }

    func loadPracticeQuestions(mode: PracticeMode, limit: Int, category: String?, year: Int?, keyword: String?) throws -> [Question] {
        let query = try makeQuestionQuery(category: category, year: year, keyword: keyword, wrongOnly: mode == .wrongOnly)
        let selectedRows: [QuestionRow]

        switch mode {
        case .sequential:
            let rows = try fetchQuestionRows(
                sql: """
                \(questionSelectSQL)
                \(query.fromClause)
                \(query.whereClause)
                ORDER BY questions.year DESC, questions.id ASC
                ;
                """,
                bindings: query.bindings
            )
            selectedRows = Array(deduplicatedQuestionRows(rows).prefix(limit))
        case .random, .mockExam, .wrongOnly:
            var rows = deduplicatedQuestionRows(
                try fetchQuestionRows(
                sql: """
                \(questionSelectSQL)
                \(query.fromClause)
                \(query.whereClause)
                ORDER BY questions.year DESC, questions.id ASC;
                """,
                bindings: query.bindings
            )
            )
            rows.shuffle()
            selectedRows = Array(rows.prefix(limit))
        }

        return try makeQuestions(from: selectedRows)
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
        let rows = try fetchQuestionRows(
            sql: """
            \(questionSelectSQL)
            FROM questions
            INNER JOIN favorite_questions ON favorite_questions.question_id = questions.id
            ORDER BY favorite_questions.created_at DESC;
            """,
            bindings: []
        )

        return try makeQuestions(from: rows)
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

        let questionMap = try fetchQuestionMap(questionIDs: wrongRows.map(\.questionID))

        return wrongRows.compactMap { row in
            guard let question = questionMap[row.questionID] else {
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

    private func makeQuestionQuery(category: String?, year: Int?, keyword: String?, wrongOnly: Bool) throws -> QuestionQuery {
        var query = QuestionQuery()

        if wrongOnly {
            query.fromClause += " INNER JOIN wrong_questions ON wrong_questions.question_id = questions.id"
            query.clauses.append("wrong_questions.is_mastered = 0")
        }

        if let category, !category.isEmpty {
            query.clauses.append("questions.category = ?")
            query.bindings.append(.text(category))
        }

        if let year {
            query.clauses.append("questions.year = ?")
            query.bindings.append(.int(Int64(year)))
        }

        if let keyword, !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            if try hasSearchIndex(), let ftsQuery = makeFTSQuery(from: normalizedKeyword) {
                query.fromClause += " INNER JOIN question_search ON question_search.question_id = questions.id"
                query.clauses.append("question_search MATCH ?")
                query.bindings.append(.text(ftsQuery))
            } else {
                let pattern = "%\(normalizedKeyword)%"
                query.clauses.append(
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
                query.bindings.append(.text(pattern))
                query.bindings.append(.text(pattern))
                query.bindings.append(.text(pattern))
            }
        }

        return query
    }

    private func bulkUpsert(
        questions: [Question],
        manifest: String,
        searchManifest: String,
        searchIndexSupported: Bool
    ) throws {
        try database.transaction { db in
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

            let deleteOptionsStatement = try prepareStatement(
                database: db,
                sql: """
                DELETE FROM question_options
                WHERE question_id = ?;
                """
            )
            defer { sqlite3_finalize(deleteOptionsStatement) }

            let optionStatement = try prepareStatement(
                database: db,
                sql: """
                INSERT INTO question_options (question_id, label, content, display_order)
                VALUES (?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(optionStatement) }

            let deleteKnowledgePointsStatement = try prepareStatement(
                database: db,
                sql: """
                DELETE FROM question_knowledge_points
                WHERE question_id = ?;
                """
            )
            defer { sqlite3_finalize(deleteKnowledgePointsStatement) }

            let knowledgePointStatement = try prepareStatement(
                database: db,
                sql: """
                INSERT INTO question_knowledge_points (question_id, knowledge_point)
                VALUES (?, ?);
                """
            )
            defer { sqlite3_finalize(knowledgePointStatement) }

            let metadataStatement = try prepareStatement(
                database: db,
                sql: """
                INSERT INTO app_metadata (key, value)
                VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value;
                """
            )
            defer { sqlite3_finalize(metadataStatement) }

            let deleteSearchStatement: OpaquePointer? =
                searchIndexSupported
                ? try prepareStatement(
                    database: db,
                    sql: """
                    DELETE FROM question_search;
                    """
                )
                : nil
            if let deleteSearchStatement {
                defer { sqlite3_finalize(deleteSearchStatement) }
                try executeUpdate(statement: deleteSearchStatement, bindings: [], database: db)
            }

            let searchStatement: OpaquePointer? =
                searchIndexSupported
                ? try prepareStatement(
                    database: db,
                    sql: """
                    INSERT INTO question_search (question_id, searchable_text)
                    VALUES (?, ?);
                    """
                )
                : nil
            defer {
                if let searchStatement {
                    sqlite3_finalize(searchStatement)
                }
            }

            for question in questions {
                let answersText = try encodedAnswers(question.correctAnswers)

                try executeUpdate(
                    statement: questionStatement,
                    bindings: [
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
                    database: db
                )

                try executeUpdate(
                    statement: deleteOptionsStatement,
                    bindings: [.int(question.id)],
                    database: db
                )

                for (index, option) in question.options.enumerated() {
                    try executeUpdate(
                        statement: optionStatement,
                        bindings: [
                            .int(question.id),
                            .text(option.label),
                            .text(option.content),
                            .int(Int64(index))
                        ],
                        database: db
                    )
                }

                try executeUpdate(
                    statement: deleteKnowledgePointsStatement,
                    bindings: [.int(question.id)],
                    database: db
                )

                for knowledgePoint in question.knowledgePoints {
                    try executeUpdate(
                        statement: knowledgePointStatement,
                        bindings: [.int(question.id), .text(knowledgePoint)],
                        database: db
                    )
                }

                if let searchStatement {
                    try executeUpdate(
                        statement: searchStatement,
                        bindings: [
                            .int(question.id),
                            .text(searchableText(for: question))
                        ],
                        database: db
                    )
                }
            }

            try executeUpdate(
                statement: metadataStatement,
                bindings: [.text(MetadataKey.questionSeedManifest), .text(manifest)],
                database: db
            )

            if searchIndexSupported {
                try executeUpdate(
                    statement: metadataStatement,
                    bindings: [.text(MetadataKey.questionSearchManifest), .text(searchManifest)],
                    database: db
                )
            }
        }
    }

    private func executeUpdate(statement: OpaquePointer?, bindings: [SQLiteBindingValue], database db: OpaquePointer) throws {
        sqlite3_reset(statement)
        sqlite3_clear_bindings(statement)
        try bind(bindings, to: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.stepFailed(database.lastErrorMessage(db))
        }
    }

    private func questionCount() throws -> Int {
        try database.read { db in
            let statement = try prepareStatement(database: db, sql: "SELECT COUNT(*) FROM questions;")
            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return Int(sqlite3_column_int(statement, 0))
        }
    }

    private func searchIndexCount() throws -> Int {
        guard try hasSearchIndex() else {
            return 0
        }

        return try database.read { db in
            let statement = try prepareStatement(database: db, sql: "SELECT COUNT(*) FROM question_search;")
            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return 0
            }

            return Int(sqlite3_column_int(statement, 0))
        }
    }

    private func metadataValue(for key: String) throws -> String? {
        try database.read { db in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT value
                FROM app_metadata
                WHERE key = ?
                LIMIT 1;
                """
            )
            defer { sqlite3_finalize(statement) }
            try bind([.text(key)], to: statement)

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return nil
            }

            return columnText(statement, index: 0)
        }
    }

    private func hasSearchIndex() throws -> Bool {
        try database.read { db in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT 1
                FROM sqlite_master
                WHERE name = 'question_search'
                LIMIT 1;
                """
            )
            defer { sqlite3_finalize(statement) }

            return sqlite3_step(statement) == SQLITE_ROW
        }
    }

    private func rebuildSearchIndex(searchManifest: String) throws {
        guard try hasSearchIndex() else { return }

        let rows = try database.read { db -> [(id: Int64, text: String)] in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT
                    questions.id,
                    questions.category,
                    questions.stage,
                    questions.stem,
                    COALESCE(GROUP_CONCAT(question_knowledge_points.knowledge_point, ' '), '') AS knowledge_points
                FROM questions
                LEFT JOIN question_knowledge_points ON question_knowledge_points.question_id = questions.id
                GROUP BY questions.id, questions.category, questions.stage, questions.stem
                ORDER BY questions.id ASC;
                """
            )
            defer { sqlite3_finalize(statement) }

            var values: [(id: Int64, text: String)] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let questionID = sqlite3_column_int64(statement, 0)
                let text = [
                    columnText(statement, index: 1),
                    columnText(statement, index: 2),
                    columnText(statement, index: 3),
                    columnText(statement, index: 4)
                ]
                .filter { !$0.isEmpty }
                .joined(separator: " ")

                values.append((id: questionID, text: text))
            }
            return values
        }

        try database.transaction { db in
            let deleteStatement = try prepareStatement(database: db, sql: "DELETE FROM question_search;")
            defer { sqlite3_finalize(deleteStatement) }
            try executeUpdate(statement: deleteStatement, bindings: [], database: db)

            let insertStatement = try prepareStatement(
                database: db,
                sql: """
                INSERT INTO question_search (question_id, searchable_text)
                VALUES (?, ?);
                """
            )
            defer { sqlite3_finalize(insertStatement) }

            let metadataStatement = try prepareStatement(
                database: db,
                sql: """
                INSERT INTO app_metadata (key, value)
                VALUES (?, ?)
                ON CONFLICT(key) DO UPDATE SET value = excluded.value;
                """
            )
            defer { sqlite3_finalize(metadataStatement) }

            for row in rows {
                try executeUpdate(
                    statement: insertStatement,
                    bindings: [.int(row.id), .text(row.text)],
                    database: db
                )
            }

            try executeUpdate(
                statement: metadataStatement,
                bindings: [.text(MetadataKey.questionSearchManifest), .text(searchManifest)],
                database: db
            )
        }
    }

    private func fetchQuestion(id: Int64) throws -> Question? {
        try fetchQuestionMap(questionIDs: [id])[id]
    }

    private func deduplicatedQuestionRows(_ rows: [QuestionRow]) -> [QuestionRow] {
        var seenKeys = Set<String>()
        var uniqueRows: [QuestionRow] = []
        uniqueRows.reserveCapacity(rows.count)

        for row in rows {
            let key = dedupeKey(for: row)
            if seenKeys.insert(key).inserted {
                uniqueRows.append(row)
            }
        }

        return uniqueRows
    }

    private func dedupeKey(for row: QuestionRow) -> String {
        let normalizedStem = normalizedQuestionStem(row.stem)
        guard !normalizedStem.isEmpty else {
            return "\(row.type.rawValue)|\(row.id)"
        }
        return "\(row.type.rawValue)|\(normalizedStem)"
    }

    private func normalizedQuestionStem(_ stem: String) -> String {
        let folded = stem.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
        let scalars = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(scalars))
    }

    private func fetchQuestionMap(questionIDs: [Int64]) throws -> [Int64: Question] {
        guard !questionIDs.isEmpty else { return [:] }

        let rows = try fetchQuestionRows(for: questionIDs)
        let questions = try makeQuestions(from: rows)
        return Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
    }

    private func fetchQuestionRows(for questionIDs: [Int64]) throws -> [QuestionRow] {
        let uniqueIDs = Array(Set(questionIDs))
        guard !uniqueIDs.isEmpty else { return [] }

        let bindings = uniqueIDs.map(SQLiteBindingValue.int)
        let placeholders = Array(repeating: "?", count: uniqueIDs.count).joined(separator: ", ")

        return try fetchQuestionRows(
            sql: """
            \(questionSelectSQL)
            FROM questions
            WHERE questions.id IN (\(placeholders));
            """,
            bindings: bindings
        )
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

    private func fetchOptions(questionIDs: [Int64]) throws -> [Int64: [QuestionOption]] {
        let uniqueIDs = Array(Set(questionIDs))
        guard !uniqueIDs.isEmpty else { return [:] }

        let placeholders = Array(repeating: "?", count: uniqueIDs.count).joined(separator: ", ")
        let bindings = uniqueIDs.map(SQLiteBindingValue.int)

        return try database.read { db in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT question_id, label, content
                FROM question_options
                WHERE question_id IN (\(placeholders))
                ORDER BY question_id ASC, display_order ASC;
                """
            )
            defer { sqlite3_finalize(statement) }
            try bind(bindings, to: statement)

            var mapping: [Int64: [QuestionOption]] = [:]

            while sqlite3_step(statement) == SQLITE_ROW {
                let questionID = sqlite3_column_int64(statement, 0)
                mapping[questionID, default: []].append(
                    QuestionOption(
                        label: columnText(statement, index: 1),
                        content: columnText(statement, index: 2)
                    )
                )
            }

            return mapping
        }
    }

    private func fetchKnowledgePoints(questionIDs: [Int64]) throws -> [Int64: [String]] {
        let uniqueIDs = Array(Set(questionIDs))
        guard !uniqueIDs.isEmpty else { return [:] }

        let placeholders = Array(repeating: "?", count: uniqueIDs.count).joined(separator: ", ")
        let bindings = uniqueIDs.map(SQLiteBindingValue.int)

        return try database.read { db in
            let statement = try prepareStatement(
                database: db,
                sql: """
                SELECT question_id, knowledge_point
                FROM question_knowledge_points
                WHERE question_id IN (\(placeholders))
                ORDER BY question_id ASC, knowledge_point ASC;
                """
            )
            defer { sqlite3_finalize(statement) }
            try bind(bindings, to: statement)

            var mapping: [Int64: [String]] = [:]

            while sqlite3_step(statement) == SQLITE_ROW {
                let questionID = sqlite3_column_int64(statement, 0)
                mapping[questionID, default: []].append(columnText(statement, index: 1))
            }

            return mapping
        }
    }

    private func makeQuestions(from rows: [QuestionRow]) throws -> [Question] {
        guard !rows.isEmpty else { return [] }

        let questionIDs = rows.map(\.id)
        let optionsByQuestionID = try fetchOptions(questionIDs: questionIDs)
        let knowledgePointsByQuestionID = try fetchKnowledgePoints(questionIDs: questionIDs)

        return rows.map { row in
            Question(
                id: row.id,
                year: row.year,
                stage: row.stage,
                type: row.type,
                category: row.category,
                knowledgePoints: knowledgePointsByQuestionID[row.id] ?? [],
                stem: row.stem,
                options: optionsByQuestionID[row.id] ?? [],
                correctAnswers: row.correctAnswers,
                analysis: row.analysis,
                score: row.score,
                estimatedMinutes: row.estimatedMinutes
            )
        }
    }

    private func encodedAnswers(_ answers: [String]) throws -> String {
        let answersData = try encoder.encode(answers)
        return String(decoding: answersData, as: UTF8.self)
    }

    private func searchableText(for question: Question) -> String {
        [
            question.category,
            question.stage,
            question.stem,
            question.knowledgePoints.joined(separator: " ")
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    private func searchManifest(for questionManifest: String) -> String {
        "question_search_v1|\(questionManifest)"
    }

    private func makeFTSQuery(from keyword: String) -> String? {
        let normalizedTokens = keyword
            .split(whereSeparator: \.isWhitespace)
            .map { token in
                token
                    .replacingOccurrences(of: "\"", with: "")
                    .replacingOccurrences(of: "'", with: "")
                    .trimmingCharacters(in: .punctuationCharacters)
            }
            .filter { !$0.isEmpty }

        guard !normalizedTokens.isEmpty else {
            return nil
        }

        guard normalizedTokens.allSatisfy({ $0.count >= 3 }) else {
            return nil
        }

        return normalizedTokens
            .map { "\"\($0)\"" }
            .joined(separator: " AND ")
    }

    private let questionSelectSQL = """
    SELECT
        questions.id,
        questions.year,
        questions.stage,
        questions.type,
        questions.category,
        questions.stem,
        questions.correct_answers,
        questions.analysis,
        questions.score,
        questions.estimated_minutes
    """
}
