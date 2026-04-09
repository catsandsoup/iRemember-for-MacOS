import Foundation
import SQLite3

nonisolated struct SQLiteRow {
    fileprivate let statement: OpaquePointer

    func int64(_ index: Int32) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return sqlite3_column_int64(statement, index)
    }

    func int(_ index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int(statement, index))
    }

    func bool(_ index: Int32) -> Bool {
        sqlite3_column_int(statement, index) != 0
    }

    func string(_ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    func data(_ index: Int32) -> Data? {
        guard let bytes = sqlite3_column_blob(statement, index) else { return nil }
        let count = Int(sqlite3_column_bytes(statement, index))
        guard count > 0 else { return nil }
        return Data(bytes: bytes, count: count)
    }
}

nonisolated enum SQLiteDatabaseError: Error, LocalizedError {
    case openFailed(path: String, code: Int32, message: String)
    case prepareFailed(sql: String, code: Int32, message: String)
    case bindFailed(index: Int32, code: Int32, message: String)
    case stepFailed(sql: String, code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let path, _, let message):
            "Unable to open \(path): \(message)"
        case .prepareFailed(_, _, let message):
            "Unable to prepare query: \(message)"
        case .bindFailed(let index, _, let message):
            "Unable to bind SQLite parameter \(index): \(message)"
        case .stepFailed(_, _, let message):
            "SQLite query failed: \(message)"
        }
    }

    var sqliteCode: Int32 {
        switch self {
        case .openFailed(_, let code, _),
                .prepareFailed(_, let code, _),
                .bindFailed(_, let code, _),
                .stepFailed(_, let code, _):
            code
        }
    }
}

nonisolated final class MessagesDatabase: @unchecked Sendable {
    private let path: String
    private let connection: OpaquePointer

    init(url: URL) throws {
        self.path = url.path
        var rawConnection: OpaquePointer?

        let openCode = sqlite3_open_v2(
            url.absoluteString,
            &rawConnection,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard openCode == SQLITE_OK, let rawConnection else {
            let message = rawConnection.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            sqlite3_close(rawConnection)
            throw SQLiteDatabaseError.openFailed(path: url.path, code: openCode, message: message)
        }

        self.connection = rawConnection
        sqlite3_busy_timeout(rawConnection, 1_500)
        sqlite3_extended_result_codes(rawConnection, 1)
    }

    deinit {
        sqlite3_close_v2(connection)
    }

    func readRows(
        sql: String,
        bind: ((OpaquePointer) throws -> Void)? = nil,
        handleRow: (SQLiteRow) throws -> Void
    ) throws {
        var statement: OpaquePointer?
        let prepareCode = sqlite3_prepare_v2(connection, sql, -1, &statement, nil)
        guard prepareCode == SQLITE_OK, let statement else {
            throw SQLiteDatabaseError.prepareFailed(
                sql: sql,
                code: prepareCode,
                message: String(cString: sqlite3_errmsg(connection))
            )
        }

        defer {
            sqlite3_finalize(statement)
        }

        if let bind {
            try bind(statement)
        }

        while true {
            let stepCode = sqlite3_step(statement)

            switch stepCode {
            case SQLITE_ROW:
                try handleRow(SQLiteRow(statement: statement))
            case SQLITE_DONE:
                return
            default:
                throw SQLiteDatabaseError.stepFailed(
                    sql: sql,
                    code: stepCode,
                    message: String(cString: sqlite3_errmsg(connection))
                )
            }
        }
    }

    func bind(int64: Int64, at index: Int32, in statement: OpaquePointer) throws {
        let code = sqlite3_bind_int64(statement, index, int64)
        guard code == SQLITE_OK else {
            throw SQLiteDatabaseError.bindFailed(index: index, code: code, message: String(cString: sqlite3_errmsg(connection)))
        }
    }

    func bind(string: String, at index: Int32, in statement: OpaquePointer) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let code = sqlite3_bind_text(statement, index, string, -1, transient)
        guard code == SQLITE_OK else {
            throw SQLiteDatabaseError.bindFailed(index: index, code: code, message: String(cString: sqlite3_errmsg(connection)))
        }
    }
}

extension URL {
    nonisolated var sqliteReadOnlyURI: URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false) ?? URLComponents()
        components.scheme = "file"
        components.path = path
        components.percentEncodedQuery = "mode=ro"
        return components.url ?? self
    }
}
