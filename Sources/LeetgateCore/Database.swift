import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum DatabaseError: Error, Equatable {
    case open(String)
    case prepare(String)
    case step(String)
}

/// The only place SQL lives. Timestamps are stored as integer epoch seconds;
/// all day arithmetic happens in `DayWindow`, never in SQL.
public final class Database {
    private var handle: OpaquePointer?

    public init(path: String) throws {
        guard sqlite3_open(path, &handle) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw DatabaseError.open(message)
        }
        try exec("PRAGMA journal_mode=WAL;")
        try exec("PRAGMA foreign_keys=ON;")
    }

    deinit { if let handle { sqlite3_close(handle) } }

    public func migrate() throws {
        try exec("""
        CREATE TABLE IF NOT EXISTS submissions (
            slug TEXT NOT NULL,
            submitted_at INTEGER NOT NULL,
            status TEXT NOT NULL,
            lang TEXT NOT NULL,
            PRIMARY KEY (slug, submitted_at)
        );
        CREATE TABLE IF NOT EXISTS reviews (
            slug TEXT PRIMARY KEY,
            stage INTEGER NOT NULL,
            due_date INTEGER NOT NULL,
            last_solved_at INTEGER NOT NULL,
            lapses INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS overrides (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL,
            reason TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        );
        """)
    }

    // MARK: - Submissions

    public func recordSubmission(_ s: Submission) throws {
        // The composite primary key makes ingest idempotent: re-syncing the same
        // window repeatedly is a no-op, while a genuine re-solve has a different
        // timestamp and therefore lands as a new row.
        try run(
            "INSERT OR IGNORE INTO submissions (slug, submitted_at, status, lang) VALUES (?, ?, ?, ?);",
            bind: { stmt in
                sqlite3_bind_text(stmt, 1, s.slug, -1, SQLITE_TRANSIENT)
                sqlite3_bind_int64(stmt, 2, Int64(s.submittedAt.timeIntervalSince1970))
                sqlite3_bind_text(stmt, 3, s.status, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 4, s.lang, -1, SQLITE_TRANSIENT)
            }
        )
    }

    public func submissions(since: Date) throws -> [Submission] {
        try query(
            "SELECT slug, submitted_at, status, lang FROM submissions WHERE submitted_at >= ? ORDER BY submitted_at ASC;",
            bind: { sqlite3_bind_int64($0, 1, Int64(since.timeIntervalSince1970)) },
            map: { stmt in
                Submission(
                    slug: String(cString: sqlite3_column_text(stmt, 0)),
                    submittedAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 1))),
                    status: String(cString: sqlite3_column_text(stmt, 2)),
                    lang: String(cString: sqlite3_column_text(stmt, 3))
                )
            }
        )
    }

    public func acceptedSlugs() throws -> Set<String> {
        let rows = try query(
            "SELECT DISTINCT slug FROM submissions WHERE status = 'Accepted';",
            bind: { _ in },
            map: { String(cString: sqlite3_column_text($0, 0)) }
        )
        return Set(rows)
    }

    // MARK: - Reviews

    public func reviews() throws -> [ReviewState] {
        try query(
            "SELECT slug, stage, due_date, last_solved_at, lapses FROM reviews ORDER BY due_date ASC;",
            bind: { _ in },
            map: { stmt in
                ReviewState(
                    slug: String(cString: sqlite3_column_text(stmt, 0)),
                    stage: Int(sqlite3_column_int(stmt, 1)),
                    dueDate: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 2))),
                    lastSolvedAt: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 3))),
                    lapses: Int(sqlite3_column_int(stmt, 4))
                )
            }
        )
    }

    public func upsertReview(_ r: ReviewState) throws {
        try run("""
        INSERT INTO reviews (slug, stage, due_date, last_solved_at, lapses)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(slug) DO UPDATE SET
            stage = excluded.stage,
            due_date = excluded.due_date,
            last_solved_at = excluded.last_solved_at,
            lapses = excluded.lapses;
        """, bind: { stmt in
            sqlite3_bind_text(stmt, 1, r.slug, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 2, Int32(r.stage))
            sqlite3_bind_int64(stmt, 3, Int64(r.dueDate.timeIntervalSince1970))
            sqlite3_bind_int64(stmt, 4, Int64(r.lastSolvedAt.timeIntervalSince1970))
            sqlite3_bind_int(stmt, 5, Int32(r.lapses))
        })
    }

    public func deleteReview(slug: String) throws {
        try run("DELETE FROM reviews WHERE slug = ?;", bind: { stmt in
            sqlite3_bind_text(stmt, 1, slug, -1, SQLITE_TRANSIENT)
        })
    }

    // MARK: - Meta

    public func installedAt() throws -> Date? {
        let rows = try query(
            "SELECT value FROM meta WHERE key = 'installed_at';",
            bind: { _ in },
            map: { String(cString: sqlite3_column_text($0, 0)) }
        )
        return rows.first.flatMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:))
    }

    public func setInstalledAt(_ date: Date) throws {
        try run(
            "INSERT INTO meta (key, value) VALUES ('installed_at', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;",
            bind: { stmt in
                sqlite3_bind_text(stmt, 1, String(Int(date.timeIntervalSince1970)), -1, SQLITE_TRANSIENT)
            }
        )
    }

    // MARK: - Overrides

    public func recordOverride(expiresAt: Date, reason: String, now: Date) throws {
        try run(
            "INSERT INTO overrides (started_at, expires_at, reason) VALUES (?, ?, ?);",
            bind: { stmt in
                sqlite3_bind_int64(stmt, 1, Int64(now.timeIntervalSince1970))
                sqlite3_bind_int64(stmt, 2, Int64(expiresAt.timeIntervalSince1970))
                sqlite3_bind_text(stmt, 3, reason, -1, SQLITE_TRANSIENT)
            }
        )
    }

    public func activeOverride(now: Date) throws -> (expiresAt: Date, reason: String)? {
        let rows = try query(
            "SELECT expires_at, reason FROM overrides WHERE expires_at > ? ORDER BY expires_at DESC LIMIT 1;",
            bind: { sqlite3_bind_int64($0, 1, Int64(now.timeIntervalSince1970)) },
            map: { stmt in
                (Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(stmt, 0))),
                 String(cString: sqlite3_column_text(stmt, 1)))
            }
        )
        return rows.first
    }

    // MARK: - Plumbing

    private func exec(_ sql: String) throws {
        var error: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(handle, sql, nil, nil, &error) == SQLITE_OK else {
            let message = error.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(error)
            throw DatabaseError.step(message)
        }
    }

    private func run(_ sql: String, bind: (OpaquePointer?) -> Void) throws {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.step(String(cString: sqlite3_errmsg(handle)))
        }
    }

    private func query<T>(
        _ sql: String,
        bind: (OpaquePointer?) -> Void,
        map: (OpaquePointer?) -> T
    ) throws -> [T] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepare(String(cString: sqlite3_errmsg(handle)))
        }
        defer { sqlite3_finalize(stmt) }
        bind(stmt)

        var results: [T] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(map(stmt))
        }
        return results
    }
}
