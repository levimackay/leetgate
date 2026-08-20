import Testing
import Foundation
@testable import LeetgateCore

@Test func gateStateIsLockedWhenAnythingOutstanding() {
    let outstanding = Outstanding(newSlug: "two-sum", reviewSlugs: [])
    #expect(!outstanding.isEmpty)
    #expect(GateState.locked(outstanding).isLocked)
}

@Test func gateStateUnlockedWhenNothingOutstanding() {
    #expect(!GateState.unlocked(.quotaMet).isLocked)
}

@Test func submissionIsAcceptedOnlyForExactStatus() {
    let at = Date(timeIntervalSince1970: 1_787_097_600)
    #expect(Submission(slug: "two-sum", submittedAt: at, status: "Accepted", lang: "csharp").isAccepted)
    #expect(!Submission(slug: "two-sum", submittedAt: at, status: "Wrong Answer", lang: "csharp").isAccepted)
    #expect(!Submission(slug: "two-sum", submittedAt: at, status: "Accepted ", lang: "csharp").isAccepted)
}

@Test func gradeParsesFromCLIStrings() {
    #expect(Grade(rawValue: "easy") == .easy)
    #expect(Grade(rawValue: "hard") == .hard)
    #expect(Grade(rawValue: "failed") == .failed)
    #expect(Grade(rawValue: "medium") == nil)
}
