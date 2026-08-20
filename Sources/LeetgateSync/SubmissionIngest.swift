import Foundation
import LeetgateCore

public enum SubmissionIngest {
    /// Fetch and persist submissions made at or after `installedAt`.
    /// Returns how many new rows were stored.
    ///
    /// The pre-install cutoff matters: history predating installation was not
    /// produced under this system's rules and must never satisfy a quota.
    @discardableResult
    public static func sync(
        client: LeetCodeClient,
        database: Database,
        config: Config,
        installedAt: Date
    ) async throws -> Int {
        let fetched = try await client.recentSubmissions(username: config.username, limit: 20)
        let relevant = fetched.filter { $0.submittedAt >= installedAt }

        let before = try database.submissions(since: installedAt).count
        for submission in relevant {
            try database.recordSubmission(submission)
        }
        let after = try database.submissions(since: installedAt).count

        return after - before
    }
}
