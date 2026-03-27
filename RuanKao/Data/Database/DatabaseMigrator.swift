import Foundation
import SQLite3

enum DatabaseMigrator {
    static func migrate(database: SQLiteDatabase) throws {
        try migrateLegacyQuestionOptionsIfNeeded(database: database)

        let statements = [
            """
            CREATE TABLE IF NOT EXISTS questions (
                id INTEGER PRIMARY KEY,
                year INTEGER NOT NULL,
                stage TEXT NOT NULL,
                type TEXT NOT NULL,
                category TEXT NOT NULL,
                stem TEXT NOT NULL,
                correct_answers TEXT NOT NULL,
                analysis TEXT NOT NULL,
                score REAL NOT NULL,
                estimated_minutes INTEGER NOT NULL
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS question_options (
                question_id INTEGER NOT NULL,
                label TEXT NOT NULL,
                content TEXT NOT NULL,
                display_order INTEGER NOT NULL,
                PRIMARY KEY (question_id, label),
                FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS question_knowledge_points (
                question_id INTEGER NOT NULL,
                knowledge_point TEXT NOT NULL,
                PRIMARY KEY (question_id, knowledge_point),
                FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS attempt_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                question_id INTEGER NOT NULL,
                selected_answers TEXT NOT NULL,
                is_correct INTEGER NOT NULL,
                spent_seconds INTEGER NOT NULL,
                attempted_at REAL NOT NULL,
                FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS wrong_questions (
                question_id INTEGER PRIMARY KEY,
                wrong_count INTEGER NOT NULL DEFAULT 0,
                last_wrong_at REAL NOT NULL,
                is_mastered INTEGER NOT NULL DEFAULT 0,
                FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS favorite_questions (
                question_id INTEGER PRIMARY KEY,
                created_at REAL NOT NULL,
                FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS question_annotations (
                question_id INTEGER PRIMARY KEY,
                note TEXT NOT NULL DEFAULT '',
                tags TEXT NOT NULL DEFAULT '[]',
                subjective_review TEXT,
                updated_at REAL NOT NULL,
                FOREIGN KEY (question_id) REFERENCES questions(id) ON DELETE CASCADE
            );
            """,
            """
            CREATE TABLE IF NOT EXISTS app_metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            """,
            "CREATE INDEX IF NOT EXISTS idx_questions_category ON questions(category);",
            "CREATE INDEX IF NOT EXISTS idx_questions_year ON questions(year);",
            "CREATE INDEX IF NOT EXISTS idx_questions_category_year ON questions(category, year DESC);",
            "CREATE INDEX IF NOT EXISTS idx_attempt_records_question ON attempt_records(question_id);",
            "CREATE INDEX IF NOT EXISTS idx_attempt_records_time ON attempt_records(attempted_at);",
            "CREATE INDEX IF NOT EXISTS idx_wrong_questions_mastered_time ON wrong_questions(is_mastered, last_wrong_at DESC);",
            "CREATE INDEX IF NOT EXISTS idx_knowledge_points_name ON question_knowledge_points(knowledge_point);",
            "CREATE INDEX IF NOT EXISTS idx_question_options_question_order ON question_options(question_id, display_order);",
            "CREATE INDEX IF NOT EXISTS idx_favorite_questions_created_at ON favorite_questions(created_at);",
            "CREATE INDEX IF NOT EXISTS idx_question_annotations_updated_at ON question_annotations(updated_at DESC);"
        ]

        try statements.forEach(database.execute)
        try migrateSearchIndexIfSupported(database: database)
    }

    private static func migrateLegacyQuestionOptionsIfNeeded(database: SQLiteDatabase) throws {
        let needsMigration = try database.read { db -> Bool in
            let statement = try prepareStatement(database: db, sql: "PRAGMA table_info(question_options);")
            defer { sqlite3_finalize(statement) }

            var columns: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                columns.append(columnText(statement, index: 1))
            }

            return columns.contains("id")
        }

        guard needsMigration else { return }
        try database.execute("DROP TABLE IF EXISTS question_options;")
    }

    private static func migrateSearchIndexIfSupported(database: SQLiteDatabase) throws {
        let sql = """
        CREATE VIRTUAL TABLE IF NOT EXISTS question_search
        USING fts5(
            question_id UNINDEXED,
            searchable_text,
            tokenize = 'trigram'
        );
        """

        try? database.execute(sql)
    }
}
