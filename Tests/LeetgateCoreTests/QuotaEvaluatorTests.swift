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

private let seed: [SeedProblem] = [
    SeedProblem(slug: "two-sum", title: "Two Sum", difficulty: .easy, pattern: "Arrays & Hashing", seq: 0),
    SeedProblem(slug: "contains-duplicate", title: "Contains Duplicate", difficulty: .easy, pattern: "Arrays & Hashing", seq: 1),
    SeedProblem(slug: "valid-anagram", title: "Valid Anagram", difficulty: .easy, pattern: "Arrays & Hashing", seq: 2),
]

private let today = date("2026-08-19T09:00:00-06:00")

private func review(_ slug: String, due: String) -> ReviewState {
    ReviewState(slug: slug, stage: 0, dueDate: date(due),
                lastSolvedAt: date("2026-08-18T20:00:00-06:00"), lapses: 0)
}

@Test func planPicksTheFirstUnsolvedSeedProblem() {
    let plan = QuotaEvaluator.plan(seed: seed, solvedSlugs: [], reviews: [],
                                   today: today, calendar: denver(), reviewCap: 5)
    #expect(plan.newSlug == "two-sum")
    #expect(plan.reviewSlugs.isEmpty)
}

@Test func planSkipsAlreadySolvedSeedProblems() {
    let plan = QuotaEvaluator.plan(seed: seed, solvedSlugs: ["two-sum", "contains-duplicate"],
                                   reviews: [], today: today, calendar: denver(), reviewCap: 5)
    #expect(plan.newSlug == "valid-anagram")
}

@Test func planYieldsNoNewProblemWhenSeedExhausted() {
    let plan = QuotaEvaluator.plan(seed: seed,
                                   solvedSlugs: ["two-sum", "contains-duplicate", "valid-anagram"],
                                   reviews: [], today: today, calendar: denver(), reviewCap: 5)
    #expect(plan.newSlug == nil)
}

@Test func planIncludesReviewsDueTodayAndOverdue() {
    let reviews = [
        review("a", due: "2026-08-19T00:00:00-06:00"),   // due today
        review("b", due: "2026-08-17T00:00:00-06:00"),   // overdue
        review("c", due: "2026-08-21T00:00:00-06:00"),   // not yet due
    ]
    let plan = QuotaEvaluator.plan(seed: seed, solvedSlugs: [], reviews: reviews,
                                   today: today, calendar: denver(), reviewCap: 5)
    #expect(Set(plan.reviewSlugs) == Set(["a", "b"]))
}

@Test func reviewCapDefersOverflowMostOverdueFirst() {
    let reviews = [
        review("newest", due: "2026-08-19T00:00:00-06:00"),
        review("older", due: "2026-08-17T00:00:00-06:00"),
        review("oldest", due: "2026-08-15T00:00:00-06:00"),
    ]
    let plan = QuotaEvaluator.plan(seed: seed, solvedSlugs: [], reviews: reviews,
                                   today: today, calendar: denver(), reviewCap: 2)
    #expect(plan.reviewSlugs == ["oldest", "older"])
    #expect(plan.deferredReviewSlugs == ["newest"])
}

@Test func gateLockedWhenNothingSubmitted() {
    let plan = DayPlan(newSlug: "two-sum", reviewSlugs: ["a"], deferredReviewSlugs: [])
    let state = QuotaEvaluator.evaluate(plan: plan, submissions: [], today: today, calendar: denver())
    #expect(state == .locked(Outstanding(newSlug: "two-sum", reviewSlugs: ["a"])))
}

@Test func gateUnlockedWhenEverythingAcceptedToday() {
    let plan = DayPlan(newSlug: "two-sum", reviewSlugs: ["a"], deferredReviewSlugs: [])
    let subs = [
        Submission(slug: "two-sum", submittedAt: date("2026-08-19T10:00:00-06:00"), status: "Accepted", lang: "csharp"),
        Submission(slug: "a", submittedAt: date("2026-08-19T10:30:00-06:00"), status: "Accepted", lang: "csharp"),
    ]
    let state = QuotaEvaluator.evaluate(plan: plan, submissions: subs, today: today, calendar: denver())
    #expect(state == .unlocked(.quotaMet))
}

@Test func rejectedSubmissionsDoNotSatisfyTheQuota() {
    let plan = DayPlan(newSlug: "two-sum", reviewSlugs: [], deferredReviewSlugs: [])
    let subs = [
        Submission(slug: "two-sum", submittedAt: date("2026-08-19T10:00:00-06:00"), status: "Wrong Answer", lang: "csharp"),
    ]
    let state = QuotaEvaluator.evaluate(plan: plan, submissions: subs, today: today, calendar: denver())
    #expect(state == .locked(Outstanding(newSlug: "two-sum", reviewSlugs: [])))
}

@Test func yesterdaysAcceptedSubmissionDoesNotSatisfyToday() {
    let plan = DayPlan(newSlug: "two-sum", reviewSlugs: [], deferredReviewSlugs: [])
    let subs = [
        Submission(slug: "two-sum", submittedAt: date("2026-08-18T23:00:00-06:00"), status: "Accepted", lang: "csharp"),
    ]
    let state = QuotaEvaluator.evaluate(plan: plan, submissions: subs, today: today, calendar: denver())
    #expect(state.isLocked)
}

@Test func emptyPlanUnlocksImmediately() {
    let plan = DayPlan(newSlug: nil, reviewSlugs: [], deferredReviewSlugs: [])
    let state = QuotaEvaluator.evaluate(plan: plan, submissions: [], today: today, calendar: denver())
    #expect(state == .unlocked(.quotaMet))
}
