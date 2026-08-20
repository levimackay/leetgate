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

@Test func boundsCoverExactlyOneLocalDay() {
    let cal = denver()
    let (start, end) = DayWindow.bounds(containing: date("2026-08-19T15:30:00-06:00"), calendar: cal)
    #expect(cal.component(.hour, from: start) == 0)
    #expect(end.timeIntervalSince(start) == 86_400)
}

@Test func springForwardDayIsTwentyThreeHours() {
    // US DST begins 2026-03-08. That local day is 23 hours long.
    let cal = denver()
    let (start, end) = DayWindow.bounds(containing: date("2026-03-08T12:00:00-06:00"), calendar: cal)
    #expect(end.timeIntervalSince(start) == 82_800)
}

@Test func lateEveningSubmissionCountsForThatDay() {
    let cal = denver()
    let day = date("2026-08-19T12:00:00-06:00")
    let submission = date("2026-08-19T23:58:00-06:00")
    #expect(DayWindow.contains(submission, on: day, calendar: cal))
}

@Test func justAfterMidnightCountsForTheNextDay() {
    let cal = denver()
    let day = date("2026-08-19T12:00:00-06:00")
    let submission = date("2026-08-20T00:02:00-06:00")
    #expect(!DayWindow.contains(submission, on: day, calendar: cal))
}

@Test func addingDaysCrossesDSTCorrectly() {
    let cal = denver()
    let before = date("2026-03-07T12:00:00-07:00")
    let after = DayWindow.addingDays(1, to: before, calendar: cal)
    #expect(cal.component(.day, from: after) == 8)
    #expect(cal.component(.hour, from: after) == cal.component(.hour, from: before))
}
