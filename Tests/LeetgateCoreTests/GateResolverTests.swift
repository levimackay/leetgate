import Testing
import Foundation
@testable import LeetgateCore

private func denver() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Denver")!
    return c
}

private let now = Date(timeIntervalSince1970: 1_787_097_600)

private func freshDB() throws -> Database {
    let db = try Database(path: ":memory:")
    try db.migrate()
    try db.setInstalledAt(now.addingTimeInterval(-86_400))
    return db
}

@Test func lockedWhenQuotaUnmet() throws {
    let db = try freshDB()
    let state = GateResolver.resolve(database: db, config: .default, now: now,
                                     calendar: denver(), lastSyncSuccess: now)
    #expect(state.isLocked)
}

@Test func unlockedWhenTodaysNewProblemIsAccepted() throws {
    let db = try freshDB()
    try db.recordSubmission(Submission(slug: "two-sum", submittedAt: now, status: "Accepted", lang: "csharp"))
    let state = GateResolver.resolve(database: db, config: .default, now: now,
                                     calendar: denver(), lastSyncSuccess: now)
    #expect(state == .unlocked(.quotaMet))
}

@Test func activeOverrideUnlocksRegardlessOfQuota() throws {
    let db = try freshDB()
    try db.recordOverride(expiresAt: now.addingTimeInterval(3600), reason: "client emergency", now: now)
    let state = GateResolver.resolve(database: db, config: .default, now: now,
                                     calendar: denver(), lastSyncSuccess: now)
    if case .unlocked(.override) = state {} else {
        Issue.record("expected an override unlock, got \(state)")
    }
}

@Test func staleSyncStaysLockedBecauseNetworkFailsClosed() throws {
    let db = try freshDB()
    let stale = now.addingTimeInterval(-4 * 3600)
    let state = GateResolver.resolve(database: db, config: .default, now: now,
                                     calendar: denver(), lastSyncSuccess: stale)
    #expect(state.isLocked)
}

@Test func neverSyncedStaysLocked() throws {
    let db = try freshDB()
    let state = GateResolver.resolve(database: db, config: .default, now: now,
                                     calendar: denver(), lastSyncSuccess: nil)
    #expect(state.isLocked)
}

@Test func databaseFaultFailsOpenSoABugCannotBrickTheMachine() {
    let broken = try! Database(path: ":memory:")   // never migrated; every query throws
    let state = GateResolver.resolve(database: broken, config: .default, now: now,
                                     calendar: denver(), lastSyncSuccess: now)
    if case .unlocked(.systemFault) = state {} else {
        Issue.record("expected a systemFault unlock, got \(state)")
    }
}

@Test func todaysAssignmentIsStableAfterItIsSolved() throws {
    // Regression: solving today's new problem must satisfy today, not silently
    // advance the assignment to the next seed problem.
    let db = try freshDB()
    try db.recordSubmission(Submission(slug: "two-sum", submittedAt: now, status: "Accepted", lang: "csharp"))

    let state = GateResolver.resolve(database: db, config: .default, now: now,
                                     calendar: denver(), lastSyncSuccess: now)
    #expect(state == .unlocked(.quotaMet))
}

@Test func assignmentAdvancesTheFollowingDay() throws {
    let db = try freshDB()
    try db.recordSubmission(Submission(slug: "two-sum", submittedAt: now, status: "Accepted", lang: "csharp"))

    let tomorrow = DayWindow.addingDays(1, to: now, calendar: denver())
    let state = GateResolver.resolve(database: db, config: .default, now: tomorrow,
                                     calendar: denver(), lastSyncSuccess: tomorrow)
    #expect(state == .locked(Outstanding(newSlug: "contains-duplicate", reviewSlugs: [])))
}
