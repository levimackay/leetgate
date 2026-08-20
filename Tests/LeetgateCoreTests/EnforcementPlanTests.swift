import Testing
import Foundation
@testable import LeetgateCore

private let locked = GateState.locked(Outstanding(newSlug: "two-sum", reviewSlugs: []))

@Test func lockedPlanTerminatesOnlyRunningBlockedApps() {
    let plan = EnforcementPlan.for(
        state: locked,
        config: .default,
        runningBundleIDs: ["com.anthropic.claudefordesktop", "com.apple.Terminal", "com.microsoft.VSCode"]
    )
    #expect(plan.bundleIDsToTerminate == ["com.anthropic.claudefordesktop"])
}

@Test func lockedPlanRendersAHostsBlock() {
    let plan = EnforcementPlan.for(state: locked, config: .default, runningBundleIDs: [])
    #expect(plan.hostsBlock?.contains("0.0.0.0 claude.ai") == true)
    #expect(plan.hostsBlock?.contains("0.0.0.0 api.anthropic.com") == true)
}

@Test func unlockedPlanTerminatesNothingAndClearsHosts() {
    let plan = EnforcementPlan.for(
        state: .unlocked(.quotaMet),
        config: .default,
        runningBundleIDs: ["com.anthropic.claudefordesktop"]
    )
    #expect(plan.bundleIDsToTerminate.isEmpty)
    #expect(plan.hostsBlock == nil)
}

@Test func systemFaultUnlockAlsoClearsEnforcement() {
    let plan = EnforcementPlan.for(
        state: .unlocked(.systemFault("db unreadable")),
        config: .default,
        runningBundleIDs: ["com.anthropic.claudefordesktop"]
    )
    #expect(plan.bundleIDsToTerminate.isEmpty)
    #expect(plan.hostsBlock == nil)
}

@Test func leetcodeNeverAppearsInTheHostsBlock() {
    var config = Config.default
    config.blockedDomains.append("leetcode.com")
    let plan = EnforcementPlan.for(state: locked, config: config, runningBundleIDs: [])
    #expect(plan.hostsBlock?.contains("leetcode.com") == false)
}
