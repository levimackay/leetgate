import Foundation

/// Assembles the gate decision from persisted state.
///
/// Two failure directions, deliberately opposite:
///
/// - **Network / stale sync fails closed.** Otherwise toggling wifi would unlock
///   the machine. Being offline also makes practice impossible, so waiting costs
///   nothing real.
/// - **Internal faults fail open.** A corrupt or unreadable database is a bug in
///   this program, and a bug must never be able to hold the machine hostage.
public enum GateResolver {
    /// How stale a successful sync may be before the gate stops trusting it.
    public static let syncFreshness: TimeInterval = 2 * 3600

    public static func resolve(
        database: Database,
        config: Config,
        now: Date,
        calendar: Calendar,
        lastSyncSuccess: Date?
    ) -> GateState {
        do {
            if let active = try database.activeOverride(now: now) {
                return .unlocked(.override(expiresAt: active.expiresAt))
            }

            let installedAt = try database.installedAt() ?? now
            let reviews = try database.reviews()
            let submissions = try database.submissions(since: installedAt)

            // "Already solved" means solved on an earlier day. Using all-time
            // solves here would advance the assignment the instant today's problem
            // was accepted, making the day's quota impossible to satisfy.
            let (startOfToday, _) = DayWindow.bounds(containing: now, calendar: calendar)
            let solved = Set(
                submissions
                    .filter { $0.isAccepted && $0.submittedAt < startOfToday }
                    .map(\.slug)
            )

            let plan = QuotaEvaluator.plan(
                seed: Seed.problems,
                solvedSlugs: solved,
                reviews: reviews,
                today: now,
                calendar: calendar,
                reviewCap: config.reviewCap
            )

            let state = QuotaEvaluator.evaluate(
                plan: plan, submissions: submissions, today: now, calendar: calendar
            )

            // A satisfied quota is only believable if the data behind it is fresh.
            if case .unlocked = state {
                guard let last = lastSyncSuccess, now.timeIntervalSince(last) <= syncFreshness else {
                    return .locked(Outstanding(newSlug: plan.newSlug, reviewSlugs: plan.reviewSlugs))
                }
            }

            return state
        } catch {
            return .unlocked(.systemFault(String(describing: error)))
        }
    }
}
