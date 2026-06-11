import Foundation
import SQLite3

enum EventDatabaseError: LocalizedError {
    case openFailed(path: String)
    case executeFailed(message: String)
    case prepareFailed(message: String)

    var errorDescription: String? {
        switch self {
        case let .openFailed(path):
            return "Failed to open database at \(path)."
        case let .executeFailed(message):
            return "Database execution failed: \(message)"
        case let .prepareFailed(message):
            return "Database statement preparation failed: \(message)"
        }
    }
}

final class EventDatabase {
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "EventDatabase.queue")
    private(set) var fileURL: URL

    init(fileName: String = "key-events.sqlite") throws {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let bundleID = Bundle.main.bundleIdentifier ?? "system-wide-key-monitor"
        let dataDir = appSupport.appendingPathComponent(bundleID, isDirectory: true)
        try fm.createDirectory(at: dataDir, withIntermediateDirectories: true)

        fileURL = dataDir.appendingPathComponent(fileName)

        guard sqlite3_open(fileURL.path, &db) == SQLITE_OK else {
            throw EventDatabaseError.openFailed(path: fileURL.path)
        }

        try execute(
            """
            CREATE TABLE IF NOT EXISTS key_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts REAL NOT NULL,
                key_code INTEGER NOT NULL,
                key_char TEXT,
                key_identifier TEXT NOT NULL,
                mod_command INTEGER NOT NULL,
                mod_shift INTEGER NOT NULL,
                mod_option INTEGER NOT NULL,
                mod_control INTEGER NOT NULL,
                mod_caps_lock INTEGER,
                active_app_bundle_id TEXT,
                active_app_name TEXT,
                active_window_title TEXT
            );
            """
        )

        try execute("CREATE INDEX IF NOT EXISTS idx_key_events_ts ON key_events(ts);")
    }

    deinit {
        queue.sync {
            if let db {
                sqlite3_close(db)
            }
        }
    }

    func insert(_ ev: KeyEventMetadata) throws {
        try queue.sync {
            let sql =
                """
                INSERT INTO key_events (
                    ts, key_code, key_char, key_identifier,
                    mod_command, mod_shift, mod_option, mod_control, mod_caps_lock,
                    active_app_bundle_id, active_app_name, active_window_title
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw EventDatabaseError.prepareFailed(message: lastMessage)
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_double(statement, 1, ev.ts)
            sqlite3_bind_int(statement, 2, Int32(ev.keyCode))
            bindText(ev.keyChar, to: 3, in: statement)
            bindText(ev.keyIdentifier, to: 4, in: statement)
            sqlite3_bind_int(statement, 5, intBool(ev.modifiers.command))
            sqlite3_bind_int(statement, 6, intBool(ev.modifiers.shift))
            sqlite3_bind_int(statement, 7, intBool(ev.modifiers.option))
            sqlite3_bind_int(statement, 8, intBool(ev.modifiers.control))
            if let capsLock = ev.modifiers.capsLock {
                sqlite3_bind_int(statement, 9, intBool(capsLock))
            } else {
                sqlite3_bind_null(statement, 9)
            }
            bindText(ev.activeAppBundleID, to: 10, in: statement)
            bindText(ev.activeAppName, to: 11, in: statement)
            bindText(ev.activeWindowTitle, to: 12, in: statement)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw EventDatabaseError.executeFailed(message: lastMessage)
            }
        }
    }

    func fetchRecent(limit: Int) throws -> [KeyEventMetadata] {
        try queue.sync {
            let safeLimit = max(1, limit)
            let sql =
                """
                SELECT
                    ts, key_code, key_char, key_identifier,
                    mod_command, mod_shift, mod_option, mod_control, mod_caps_lock,
                    active_app_bundle_id, active_app_name, active_window_title
                FROM key_events
                ORDER BY ts DESC
                LIMIT ?;
                """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw EventDatabaseError.prepareFailed(message: lastMessage)
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int(statement, 1, Int32(safeLimit))

            var out: [KeyEventMetadata] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                out.append(readEvent(from: statement))
            }
            return out.reversed()
        }
    }

    func fetchAll() throws -> [KeyEventMetadata] {
        try queue.sync {
            let sql =
                """
                SELECT
                    ts, key_code, key_char, key_identifier,
                    mod_command, mod_shift, mod_option, mod_control, mod_caps_lock,
                    active_app_bundle_id, active_app_name, active_window_title
                FROM key_events
                ORDER BY ts ASC;
                """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw EventDatabaseError.prepareFailed(message: lastMessage)
            }
            defer { sqlite3_finalize(statement) }

            var out: [KeyEventMetadata] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                out.append(readEvent(from: statement))
            }
            return out
        }
    }

    func clear() throws {
        try execute("DELETE FROM key_events;")
    }

    func deleteEvents(olderThan cutoffTimestamp: TimeInterval) throws {
        try queue.sync {
            let sql = "DELETE FROM key_events WHERE ts < ?;"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw EventDatabaseError.prepareFailed(message: lastMessage)
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_double(statement, 1, cutoffTimestamp)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw EventDatabaseError.executeFailed(message: lastMessage)
            }
        }
    }

    func count() throws -> Int {
        try queue.sync {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM key_events;", -1, &statement, nil) == SQLITE_OK else {
                throw EventDatabaseError.prepareFailed(message: lastMessage)
            }
            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int64(statement, 0))
        }
    }

    func earliestTimestamp() throws -> TimeInterval? {
        try queue.sync {
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "SELECT MIN(ts) FROM key_events;", -1, &statement, nil) == SQLITE_OK else {
                throw EventDatabaseError.prepareFailed(message: lastMessage)
            }
            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            if sqlite3_column_type(statement, 0) == SQLITE_NULL {
                return nil
            }
            return sqlite3_column_double(statement, 0)
        }
    }

    private func execute(_ sql: String) throws {
        try queue.sync {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw EventDatabaseError.executeFailed(message: lastMessage)
            }
        }
    }

    private var lastMessage: String {
        guard let db, let cString = sqlite3_errmsg(db) else {
            return "Unknown SQLite error"
        }
        return String(cString: cString)
    }

    private func bindText(_ text: String?, to index: Int32, in statement: OpaquePointer?) {
        guard let text else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_text(statement, index, text, -1, sqliteTransient)
    }

    private func readEvent(from statement: OpaquePointer?) -> KeyEventMetadata {
        let modifiers = KeyEventMetadata.Modifiers(
            command: sqlite3_column_int(statement, 4) != 0,
            shift: sqlite3_column_int(statement, 5) != 0,
            option: sqlite3_column_int(statement, 6) != 0,
            control: sqlite3_column_int(statement, 7) != 0,
            capsLock: sqlite3_column_type(statement, 8) == SQLITE_NULL ? nil : (sqlite3_column_int(statement, 8) != 0)
        )

        return KeyEventMetadata(
            ts: sqlite3_column_double(statement, 0),
            keyCode: UInt16(sqlite3_column_int(statement, 1)),
            keyChar: sqliteText(statement, index: 2),
            keyIdentifier: sqliteText(statement, index: 3) ?? "unknown",
            modifiers: modifiers,
            activeAppBundleID: sqliteText(statement, index: 9),
            activeAppName: sqliteText(statement, index: 10),
            activeWindowTitle: sqliteText(statement, index: 11)
        )
    }

    private func sqliteText(_ statement: OpaquePointer?, index: Int32) -> String? {
        guard let raw = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: raw)
    }

    private func intBool(_ value: Bool) -> Int32 {
        value ? 1 : 0
    }

    private var sqliteTransient: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }
}