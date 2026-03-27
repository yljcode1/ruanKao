#!/usr/bin/env python3

import hashlib
import json
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
SEEDS_DIR = ROOT / "RuanKao" / "Resources" / "Seeds"
OUTPUT_DB = SEEDS_DIR / "ruankao_seed.sqlite"
OUTPUT_MANIFEST = SEEDS_DIR / "question_seed_manifest.txt"

QUESTION_SEED_KEY = "question_seed_manifest"
QUESTION_SEARCH_KEY = "question_search_manifest"

SCHEMA_STATEMENTS = [
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
]

SEARCH_INDEX_SQL = """
CREATE VIRTUAL TABLE IF NOT EXISTS question_search
USING fts5(
    question_id UNINDEXED,
    searchable_text,
    tokenize = 'trigram'
);
"""


def seed_files():
    return sorted(
        path for path in SEEDS_DIR.glob("*.json")
        if "question" in path.name.lower()
    )


def build_manifest(files):
    digest = hashlib.sha256()
    for path in files:
        digest.update(path.name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(hashlib.sha256(path.read_bytes()).digest())
        digest.update(b"\0")
    return f"question_seed_v2|sha256:{digest.hexdigest()}"


def build_search_manifest(question_manifest):
    return f"question_search_v1|{question_manifest}"


def load_questions(files):
    questions_by_id = {}

    for path in files:
        payload = json.loads(path.read_text(encoding="utf-8"))
        for question in payload:
            questions_by_id[int(question["id"])] = question

    return sorted(
        questions_by_id.values(),
        key=lambda question: (-int(question["year"]), int(question["id"]))
    )


def searchable_text(question):
    parts = [
        question.get("category", ""),
        question.get("stage", ""),
        question.get("stem", ""),
        " ".join(question.get("knowledgePoints", []))
    ]
    return " ".join(part for part in parts if part)


def write_database(database_path, questions, manifest):
    if database_path.exists():
        database_path.unlink()

    connection = sqlite3.connect(database_path)
    connection.execute("PRAGMA foreign_keys = ON;")
    connection.execute("PRAGMA journal_mode = DELETE;")
    connection.execute("PRAGMA synchronous = OFF;")

    for statement in SCHEMA_STATEMENTS:
        connection.execute(statement)

    search_index_supported = True
    try:
        connection.execute(SEARCH_INDEX_SQL)
    except sqlite3.OperationalError:
        search_index_supported = False

    question_rows = [
        (
            int(question["id"]),
            int(question["year"]),
            question["stage"],
            question["type"],
            question["category"],
            question["stem"],
            json.dumps(question["correctAnswers"], ensure_ascii=False, separators=(",", ":")),
            question["analysis"],
            float(question["score"]),
            int(question["estimatedMinutes"]),
        )
        for question in questions
    ]

    connection.executemany(
        """
        INSERT INTO questions
        (id, year, stage, type, category, stem, correct_answers, analysis, score, estimated_minutes)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """,
        question_rows,
    )

    option_rows = []
    knowledge_rows = []
    search_rows = []

    for question in questions:
        question_id = int(question["id"])

        for index, option in enumerate(question.get("options", [])):
            option_rows.append(
                (
                    question_id,
                    option["label"],
                    option["content"],
                    index,
                )
            )

        for knowledge_point in question.get("knowledgePoints", []):
            knowledge_rows.append((question_id, knowledge_point))

        if search_index_supported:
            search_rows.append((question_id, searchable_text(question)))

    if option_rows:
        connection.executemany(
            """
            INSERT INTO question_options (question_id, label, content, display_order)
            VALUES (?, ?, ?, ?);
            """,
            option_rows,
        )

    if knowledge_rows:
        connection.executemany(
            """
            INSERT INTO question_knowledge_points (question_id, knowledge_point)
            VALUES (?, ?);
            """,
            knowledge_rows,
        )

    metadata_rows = [(QUESTION_SEED_KEY, manifest)]
    if search_index_supported:
        connection.executemany(
            """
            INSERT INTO question_search (question_id, searchable_text)
            VALUES (?, ?);
            """,
            search_rows,
        )
        metadata_rows.append((QUESTION_SEARCH_KEY, build_search_manifest(manifest)))

    connection.executemany(
        """
        INSERT INTO app_metadata (key, value)
        VALUES (?, ?);
        """,
        metadata_rows,
    )

    connection.commit()
    connection.execute("VACUUM;")
    connection.close()


def main():
    files = seed_files()
    if not files:
        raise SystemExit("No seed JSON files found.")

    manifest = build_manifest(files)
    questions = load_questions(files)
    write_database(OUTPUT_DB, questions, manifest)
    OUTPUT_MANIFEST.write_text(f"{manifest}\n", encoding="utf-8")

    print(f"Wrote {len(questions)} questions to {OUTPUT_DB}")
    print(f"Wrote manifest to {OUTPUT_MANIFEST}")


if __name__ == "__main__":
    main()
