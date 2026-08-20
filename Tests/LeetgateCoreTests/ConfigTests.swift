import Testing
import Foundation
@testable import LeetgateCore

@Test func defaultConfigMatchesTheSpec() {
    let c = Config.default
    #expect(c.username == "lmack03")
    #expect(c.reviewCap == 5)
    #expect(c.newProblemsPerDay == 1)
    #expect(c.blockedBundleIDs.contains("com.anthropic.claudefordesktop"))
    #expect(c.blockedDomains.contains("claude.ai"))
    #expect(c.blockedDomains.contains("api.anthropic.com"))
}

@Test func editorsAndTerminalAreNeverBlocked() {
    let forbidden = [
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",  // Cursor
        "com.apple.Terminal",
        "com.googlecode.iterm2",
    ]
    for id in forbidden {
        #expect(!Config.default.blockedBundleIDs.contains(id))
    }
}

@Test func leetcodeIsNeverInTheBlockedDomains() {
    #expect(!Config.default.blockedDomains.contains("leetcode.com"))
}

@Test func configRoundTripsThroughJSON() throws {
    let data = try JSONEncoder().encode(Config.default)
    let decoded = try JSONDecoder().decode(Config.self, from: data)
    #expect(decoded == Config.default)
}

@Test func seedIsOrderedAndStartsWithTwoSum() {
    #expect(Seed.problems.first?.slug == "two-sum")
    #expect(Seed.problems.map(\.seq) == Array(0..<Seed.problems.count))
}

@Test func seedContainsOnlyEasyProblemsInV1() {
    #expect(Seed.problems.allSatisfy { $0.difficulty == .easy })
}

@Test func seedSlugsAreUnique() {
    #expect(Set(Seed.problems.map(\.slug)).count == Seed.problems.count)
}
