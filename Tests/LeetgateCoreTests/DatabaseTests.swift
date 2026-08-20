import Testing
import Foundation
@testable import LeetgateCore

private func makeDB() throws -> Database {
    let db = try Database(path: ":memory:")
    try db.migrate()
    return db
}

private let t0 = Date(timeIntervalSince1970: 1_787_097_600)

@Test func migrateIsIdempotent() throws {
    let db = try Database(path: ":memory:")
    try db.migrate()
    try db.migrate()
    #expect(try db.reviews().isEmpty)
}

@Test func submissionsRoundTrip() throws {
    let db = try makeDB()
    let s = Submission(slug: "two-sum", submittedAt: t0, status: "Accepted", lang: "csharp")
    try db.recordSubmission(s)
    let fetched = try db.submissions(since: t0.addingTimeInterval(-60))
    #expect(fetched == [s])
}

@Test func recordingTheSameSubmissionTwiceStoresOneRow() throws {
    let db = try makeDB()
    let s = Submission(slug: "two-sum", submittedAt: t0, status: "Accepted", lang: "csharp")
    try db.recordSubmission(s)
    try db.recordSubmission(s)
    #expect(try db.submissions(since: t0.addingTimeInterval(-60)).count == 1)
}

@Test func aResolveOfTheSameProblemIsADistinctRow() throws {
    let db = try makeDB()
    try db.recordSubmission(Submission(slug: "two-sum", submittedAt: t0, status: "Accepted", lang: "csharp"))
    try db.recordSubmission(Submission(slug: "two-sum", submittedAt: t0.addingTimeInterval(86_400), status: "Accepted", lang: "csharp"))
    #expect(try db.submissions(since: t0.addingTimeInterval(-60)).count == 2)
}

@Test func acceptedSlugsExcludesFailures() throws {
    let db = try makeDB()
    try db.recordSubmission(Submission(slug: "two-sum", submittedAt: t0, status: "Accepted", lang: "csharp"))
    try db.recordSubmission(Submission(slug: "valid-anagram", submittedAt: t0, status: "Wrong Answer", lang: "csharp"))
    #expect(try db.acceptedSlugs() == ["two-sum"])
}

@Test func reviewsUpsertAndDelete() throws {
    let db = try makeDB()
    let r = ReviewState(slug: "two-sum", stage: 0, dueDate: t0, lastSolvedAt: t0, lapses: 0)
    try db.upsertReview(r)
    #expect(try db.reviews() == [r])

    var updated = r
    updated.stage = 2
    updated.lapses = 1
    try db.upsertReview(updated)
    #expect(try db.reviews() == [updated])

    try db.deleteReview(slug: "two-sum")
    #expect(try db.reviews().isEmpty)
}

@Test func installedAtPersists() throws {
    let db = try makeDB()
    #expect(try db.installedAt() == nil)
    try db.setInstalledAt(t0)
    #expect(try db.installedAt() == t0)
}

@Test func activeOverrideExpires() throws {
    let db = try makeDB()
    try db.recordOverride(expiresAt: t0.addingTimeInterval(3600), reason: "client emergency", now: t0)
    #expect(try db.activeOverride(now: t0)?.reason == "client emergency")
    #expect(try db.activeOverride(now: t0.addingTimeInterval(7200)) == nil)
}
