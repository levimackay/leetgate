import Testing
import Foundation
@testable import LeetgateSync
@testable import LeetgateCore

/// Full pipeline over a real captured API response: parse, persist, resolve.
/// The fixture is an unmodified `recentSubmissionList` payload for the account
/// this system was built for, so the parser is exercised against real shapes
/// rather than shapes invented to match the parser.
private struct FixtureTransport: HTTPTransport {
    func post(url: URL, body: Data, headers: [String: String]) async throws -> (Data, Int) {
        let path = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures-lmack03.json")
        return (try Data(contentsOf: path), 200)
    }
}

private func denver() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Denver")!
    return c
}

private func tempDB() throws -> Database {
    let path = NSTemporaryDirectory() + "leetgate-e2e-\(UUID().uuidString).db"
    let db = try Database(path: path)
    try db.migrate()
    return db
}

@Test func realResponseParsesAndPersists() async throws {
    let db = try tempDB()
    let client = LeetCodeClient(transport: FixtureTransport())

    let fetched = try await SubmissionIngest.fetch(client: client, config: .default)
    #expect(fetched.count == 9)
    #expect(fetched.allSatisfy { !$0.slug.isEmpty && !$0.lang.isEmpty })

    try SubmissionIngest.store(fetched, database: db, installedAt: .distantPast)
    #expect(try db.submissions(since: .distantPast).count == 9)
}

@Test func realHistoryContainsRepeatSolvesOfTheSameProblem() async throws {
    // The spaced-repetition design depends on a re-solve being a distinct row.
    // This account solved two-sum and palindrome-number twice each; both pairs
    // must survive as separate submissions.
    let client = LeetCodeClient(transport: FixtureTransport())
    let fetched = try await SubmissionIngest.fetch(client: client, config: .default)

    let counts = Dictionary(grouping: fetched, by: \.slug).mapValues(\.count)
    #expect(counts["two-sum"] == 2)
    #expect(counts["palindrome-number"] == 2)

    let db = try tempDB()
    try SubmissionIngest.store(fetched, database: db, installedAt: .distantPast)
    let stored = try db.submissions(since: .distantPast).filter { $0.slug == "two-sum" }
    #expect(stored.count == 2)
    #expect(stored[0].submittedAt != stored[1].submittedAt)
}

@Test func historicalSolvesDoNotUnlockAFreshInstall() async throws {
    // Everything in this fixture predates installation, so day one must still
    // be locked on two-sum. If this ever passes as unlocked, the pre-install
    // cutoff has regressed and pre-install history would satisfy a quota.
    let db = try tempDB()
    let now = Date()
    try db.setInstalledAt(now)

    let client = LeetCodeClient(transport: FixtureTransport())
    let fetched = try await SubmissionIngest.fetch(client: client, config: .default)
    let stored = try SubmissionIngest.store(fetched, database: db, installedAt: now)

    #expect(stored == 0)

    let state = GateResolver.resolve(
        database: db, config: .default, now: now, calendar: denver(), lastSyncSuccess: now
    )
    #expect(state == .locked(Outstanding(newSlug: "two-sum", reviewSlugs: [])))
}
