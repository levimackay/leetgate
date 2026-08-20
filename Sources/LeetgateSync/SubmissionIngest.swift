import Foundation
import LeetgateCore

public enum SubmissionIngest {
    /// Network half. Kept separate from persistence so that the awaiting caller
    /// never has to carry a `Database` across an isolation boundary.
    public static func fetch(client: LeetCodeClient, config: Config) async throws -> [Submission] {
        try await client.recentSubmissions(username: config.username, limit: 20)
    }

    /// Persistence half. Returns how many new rows were stored.
    ///
    /// The pre-install cutoff matters: history predating installation was not
    /// produced under this system's rules and must never satisfy a quota.
    @discardableResult
    public static func store(
        _ submissions: [Submission],
        database: Database,
        installedAt: Date
    ) throws -> Int {
        let relevant = submissions.filter { $0.submittedAt >= installedAt }

        let before = try database.submissions(since: installedAt).count
        for submission in relevant {
            try database.recordSubmission(submission)
        }
        let after = try database.submissions(since: installedAt).count

        return after - before
    }

    /// Convenience for callers with no isolation constraints.
    @discardableResult
    public static func sync(
        client: LeetCodeClient,
        database: Database,
        config: Config,
        installedAt: Date
    ) async throws -> Int {
        let fetched = try await fetch(client: client, config: config)
        return try store(fetched, database: database, installedAt: installedAt)
    }
}
