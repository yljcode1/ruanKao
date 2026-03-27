import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum SQLiteError: LocalizedError {
    case openFailed(String)
    case executeFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case stepFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message),
             .executeFailed(let message),
             .prepareFailed(let message),
             .bindFailed(let message),
             .stepFailed(let message):
            return message
        }
    }
}

enum SQLiteBindingValue {
    case int(Int64)
    case double(Double)
    case text(String)
    case bool(Bool)
    case null
}

final class SQLiteDatabase {
    private let handle: OpaquePointer
    private let queue = DispatchQueue(label: "com.codexdemo.ruankao.database")

    init(databaseName: String) throws {
        let fileManager = FileManager.default
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let appFolder = baseURL.appendingPathComponent("RuanKao", isDirectory: true)
        try fileManager.createDirectory(at: appFolder, withIntermediateDirectories: true, attributes: nil)

        let databaseURL = appFolder.appendingPathComponent(databaseName)
        var pointer: OpaquePointer?

        guard sqlite3_open(databaseURL.path, &pointer) == SQLITE_OK, let pointer else {
            throw SQLiteError.openFailed("Unable to open database at \(databaseURL.path)")
        }

        self.handle = pointer
        try execute("PRAGMA foreign_keys = ON;")
    }

    deinit {
        sqlite3_close(handle)
    }

    func read<T>(_ block: (OpaquePointer) throws -> T) throws -> T {
        try queue.sync {
            try block(handle)
        }
    }

    func write<T>(_ block: (OpaquePointer) throws -> T) throws -> T {
        try queue.sync {
            try block(handle)
        }
    }

    func execute(_ sql: String) throws {
        try write { db in
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw SQLiteError.executeFailed(lastErrorMessage(db))
            }
        }
    }

    func lastErrorMessage(_ db: OpaquePointer) -> String {
        String(cString: sqlite3_errmsg(db))
    }
}

func prepareStatement(database: OpaquePointer, sql: String) throws -> OpaquePointer? {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
        throw SQLiteError.prepareFailed(String(cString: sqlite3_errmsg(database)))
    }

    return statement
}

func bind(_ value: SQLiteBindingValue, to statement: OpaquePointer?, index: Int32) throws {
    let result: Int32

    switch value {
    case .int(let number):
        result = sqlite3_bind_int64(statement, index, number)
    case .double(let number):
        result = sqlite3_bind_double(statement, index, number)
    case .text(let string):
        result = sqlite3_bind_text(statement, index, string, -1, SQLITE_TRANSIENT)
    case .bool(let boolean):
        result = sqlite3_bind_int(statement, index, boolean ? 1 : 0)
    case .null:
        result = sqlite3_bind_null(statement, index)
    }

    guard result == SQLITE_OK else {
        throw SQLiteError.bindFailed("Failed to bind parameter at index \(index)")
    }
}

func bind(_ values: [SQLiteBindingValue], to statement: OpaquePointer?) throws {
    for (offset, value) in values.enumerated() {
        try bind(value, to: statement, index: Int32(offset + 1))
    }
}

func columnText(_ statement: OpaquePointer?, index: Int32) -> String {
    guard let cString = sqlite3_column_text(statement, index) else {
        return ""
    }

    return String(cString: cString)
}

func columnBool(_ statement: OpaquePointer?, index: Int32) -> Bool {
    sqlite3_column_int(statement, index) == 1
}
