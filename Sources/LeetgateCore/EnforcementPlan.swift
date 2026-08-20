import Foundation

/// What enforcement should do right now. Pure — it takes the world as input and
/// returns intentions, so the daemon's privileged code stays trivial.
public struct EnforcementPlan: Equatable, Sendable {
    public let bundleIDsToTerminate: [String]
    /// The hosts block to install, or `nil` to remove leetgate's section entirely.
    public let hostsBlock: String?

    public init(bundleIDsToTerminate: [String], hostsBlock: String?) {
        self.bundleIDsToTerminate = bundleIDsToTerminate
        self.hostsBlock = hostsBlock
    }

    public static func `for`(
        state: GateState,
        config: Config,
        runningBundleIDs: [String]
    ) -> EnforcementPlan {
        guard state.isLocked else {
            return EnforcementPlan(bundleIDsToTerminate: [], hostsBlock: nil)
        }

        let blocked = Set(config.blockedBundleIDs)
        return EnforcementPlan(
            bundleIDsToTerminate: runningBundleIDs.filter { blocked.contains($0) },
            hostsBlock: HostsFile.render(domains: config.blockedDomains)
        )
    }
}
