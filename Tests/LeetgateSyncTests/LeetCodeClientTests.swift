import Testing
import Foundation
@testable import LeetgateSync
@testable import LeetgateCore

private struct StubTransport: HTTPTransport {
    let body: String
    let status: Int
    func post(url: URL, body: Data, headers: [String: String]) async throws -> (Data, Int) {
        (self.body.data(using: .utf8)!, status)
    }
}

private struct FailingTransport: HTTPTransport {
    struct Boom: Error {}
    func post(url: URL, body: Data, headers: [String: String]) async throws -> (Data, Int) {
        throw Boom()
    }
}

private let validResponse = """
{"data":{"recentSubmissionList":[
 {"titleSlug":"greatest-common-divisor-of-strings","timestamp":"1787097638","statusDisplay":"Accepted","lang":"csharp"},
 {"titleSlug":"merge-strings-alternately","timestamp":"1787096820","statusDisplay":"Accepted","lang":"csharp"}
]}}
"""

@Test func parsesSubmissionsFromAValidResponse() async throws {
    let client = LeetCodeClient(transport: StubTransport(body: validResponse, status: 200))
    let subs = try await client.recentSubmissions(username: "lmack03", limit: 20)
    #expect(subs.count == 2)
    #expect(subs[0].slug == "greatest-common-divisor-of-strings")
    #expect(subs[0].isAccepted)
    #expect(subs[0].submittedAt == Date(timeIntervalSince1970: 1_787_097_638))
    #expect(subs[0].lang == "csharp")
}

@Test func preservesNonAcceptedStatuses() async throws {
    let body = """
    {"data":{"recentSubmissionList":[
     {"titleSlug":"two-sum","timestamp":"1787097638","statusDisplay":"Wrong Answer","lang":"csharp"}
    ]}}
    """
    let client = LeetCodeClient(transport: StubTransport(body: body, status: 200))
    let subs = try await client.recentSubmissions(username: "lmack03", limit: 20)
    #expect(!subs[0].isAccepted)
    #expect(subs[0].status == "Wrong Answer")
}

@Test func emptyListIsValidNotAnError() async throws {
    let client = LeetCodeClient(transport: StubTransport(body: #"{"data":{"recentSubmissionList":[]}}"#, status: 200))
    #expect(try await client.recentSubmissions(username: "lmack03", limit: 20).isEmpty)
}

@Test func missingFieldThrowsSchemaError() async {
    let client = LeetCodeClient(transport: StubTransport(body: #"{"data":{}}"#, status: 200))
    await #expect(throws: SyncError.self) {
        _ = try await client.recentSubmissions(username: "lmack03", limit: 20)
    }
}

@Test func graphQLErrorsThrowSchemaError() async {
    let body = #"{"errors":[{"message":"Cannot query field \"recentSubmissionList\""}]}"#
    let client = LeetCodeClient(transport: StubTransport(body: body, status: 200))
    await #expect(throws: SyncError.self) {
        _ = try await client.recentSubmissions(username: "lmack03", limit: 20)
    }
}

@Test func nonTwoHundredThrows() async {
    let client = LeetCodeClient(transport: StubTransport(body: "rate limited", status: 429))
    await #expect(throws: SyncError.self) {
        _ = try await client.recentSubmissions(username: "lmack03", limit: 20)
    }
}

@Test func transportFailureThrows() async {
    let client = LeetCodeClient(transport: FailingTransport())
    await #expect(throws: SyncError.self) {
        _ = try await client.recentSubmissions(username: "lmack03", limit: 20)
    }
}
