import Testing
import Foundation
@testable import LeetgateCore

private func denver() -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/Denver")!
    return c
}

private func date(_ iso: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: iso)!
}

@Test func intervalsMatchTheSpecifiedLadder() {
    #expect(ReviewScheduler.intervals == [1, 3, 7, 21, 60])
}

@Test func startSchedulesFirstReviewOneDayOut() {
    let cal = denver()
    let solved = date("2026-08-19T20:00:00-06:00")
    let state = ReviewScheduler.start(slug: "two-sum", solvedAt: solved, calendar: cal)
    #expect(state.stage == 0)
    #expect(state.lapses == 0)
    #expect(cal.component(.day, from: state.dueDate) == 20)
}

@Test func easyAdvancesToTheNextInterval() {
    let cal = denver()
    let solved = date("2026-08-20T20:00:00-06:00")
    let state = ReviewState(slug: "two-sum", stage: 0,
                            dueDate: date("2026-08-20T20:00:00-06:00"),
                            lastSolvedAt: date("2026-08-19T20:00:00-06:00"), lapses: 0)
    let next = ReviewScheduler.advance(state, grade: .easy, solvedAt: solved, calendar: cal)
    #expect(next?.stage == 1)
    // stage 1 interval is 3 days
    #expect(cal.component(.day, from: next!.dueDate) == 23)
    #expect(next?.lapses == 0)
}

@Test func hardRepeatsTheCurrentInterval() {
    let cal = denver()
    let solved = date("2026-08-20T20:00:00-06:00")
    let state = ReviewState(slug: "two-sum", stage: 2,
                            dueDate: date("2026-08-20T20:00:00-06:00"),
                            lastSolvedAt: date("2026-08-13T20:00:00-06:00"), lapses: 0)
    let next = ReviewScheduler.advance(state, grade: .hard, solvedAt: solved, calendar: cal)
    #expect(next?.stage == 2)
    // stage 2 interval is 7 days
    #expect(cal.component(.day, from: next!.dueDate) == 27)
}

@Test func failedResetsToStageZeroAndCountsALapse() {
    let cal = denver()
    let solved = date("2026-08-20T20:00:00-06:00")
    let state = ReviewState(slug: "two-sum", stage: 3,
                            dueDate: date("2026-08-20T20:00:00-06:00"),
                            lastSolvedAt: date("2026-07-30T20:00:00-06:00"), lapses: 1)
    let next = ReviewScheduler.advance(state, grade: .failed, solvedAt: solved, calendar: cal)
    #expect(next?.stage == 0)
    #expect(next?.lapses == 2)
    #expect(cal.component(.day, from: next!.dueDate) == 21)
}

@Test func easyAtTheFinalStageRetiresTheProblem() {
    let cal = denver()
    let solved = date("2026-08-20T20:00:00-06:00")
    let last = ReviewScheduler.intervals.count - 1
    let state = ReviewState(slug: "two-sum", stage: last,
                            dueDate: date("2026-08-20T20:00:00-06:00"),
                            lastSolvedAt: date("2026-06-21T20:00:00-06:00"), lapses: 0)
    #expect(ReviewScheduler.advance(state, grade: .easy, solvedAt: solved, calendar: cal) == nil)
}
