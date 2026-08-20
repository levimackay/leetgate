import Testing
import Foundation
@testable import LeetgateSync
@testable import LeetgateCore

private struct StubTransport: HTTPTransport {
    let body: String
    func post(url: URL, body: Data, headers: [String: String]) async throws -> (Data, Int) {
        (self.body.data(using: .utf8)!, 200)
    }
}

private let installedAt = Date(timeIntervalSince1970: 1_787_000_000)

private let response = """
{"data":{"recentSubmissionList":[
 {"titleSlug":"after-install","timestamp":"1787097638","statusDisplay":"Accepted","lang":"csharp"},
 {"titleSlug":"before-install","timestamp":"1780000000","statusDisplay":"Accepted","lang":"csharp"}
]}}
"""

@Test func ingestStoresOnlySubmissionsAfterInstall() async throws {
    let db = try Database(path: ":memory:")
    try db.migrate()
    let client = LeetCodeClient(transport: StubTransport(body: response))

    let count = try await SubmissionIngest.sync(
        client: client, database: db, config: .default, installedAt: installedAt
    )

    #expect(count == 1)
    #expect(try db.acceptedSlugs() == ["after-install"])
}

@Test func ingestIsIdempotent() async throws {
    let db = try Database(path: ":memory:")
    try db.migrate()
    let client = LeetCodeClient(transport: StubTransport(body: response))

    _ = try await SubmissionIngest.sync(client: client, database: db, config: .default, installedAt: installedAt)
    _ = try await SubmissionIngest.sync(client: client, database: db, config: .default, installedAt: installedAt)

    #expect(try db.submissions(since: installedAt).count == 1)
}
