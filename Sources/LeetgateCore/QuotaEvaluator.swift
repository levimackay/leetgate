import Foundation

/// Decides what a day requires and whether it has been satisfied.
/// Both functions are pure; all time and data are injected.
public enum QuotaEvaluator {
    /// Build today's requirement.
    ///
    /// The review cap exists so a missed streak cannot compound into a wall that
    /// forces the override. Overflow is deferred, most-overdue served first.
    public static func plan(
        seed: [SeedProblem],
        solvedSlugs: Set<String>,
        reviews: [ReviewState],
        today: Date,
        calendar: Calendar,
        reviewCap: Int
    ) -> DayPlan {
        let newSlug = seed
            .sorted { $0.seq < $1.seq }
            .first { !solvedSlugs.contains($0.slug) }?
            .slug

        let (_, endOfToday) = DayWindow.bounds(containing: today, calendar: calendar)
        let due = reviews
            .filter { $0.dueDate < endOfToday }
            .sorted { $0.dueDate < $1.dueDate }

        let scheduled = due.prefix(reviewCap).map(\.slug)
        let deferred = due.dropFirst(reviewCap).map(\.slug)

        return DayPlan(
            newSlug: newSlug,
            reviewSlugs: Array(scheduled),
            deferredReviewSlugs: Array(deferred)
        )
    }

    /// Compare the plan against submissions. Only submissions accepted within
    /// today's local-day window count.
    public static func evaluate(
        plan: DayPlan,
        submissions: [Submission],
        today: Date,
        calendar: Calendar
    ) -> GateState {
        let acceptedToday = Set(
            submissions
                .filter { $0.isAccepted && DayWindow.contains($0.submittedAt, on: today, calendar: calendar) }
                .map(\.slug)
        )

        let outstandingNew = plan.newSlug.flatMap { acceptedToday.contains($0) ? nil : $0 }
        let outstandingReviews = plan.reviewSlugs.filter { !acceptedToday.contains($0) }
        let outstanding = Outstanding(newSlug: outstandingNew, reviewSlugs: outstandingReviews)

        return outstanding.isEmpty ? .unlocked(.quotaMet) : .locked(outstanding)
    }
}
