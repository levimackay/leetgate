import Foundation

/// Fixed-interval spaced repetition. Deliberately not SM-2 for v1: without a
/// trustworthy quality signal, an ease factor is noise. The grade tunes position
/// on a fixed ladder and nothing else.
public enum ReviewScheduler {
    /// Days until the next review, indexed by stage.
    public static let intervals: [Int] = [1, 3, 7, 21, 60]

    /// First review after an initial solve.
    public static func start(slug: String, solvedAt: Date, calendar: Calendar) -> ReviewState {
        ReviewState(
            slug: slug,
            stage: 0,
            dueDate: DayWindow.addingDays(intervals[0], to: solvedAt, calendar: calendar),
            lastSolvedAt: solvedAt,
            lapses: 0
        )
    }

    /// Next state after a graded re-solve. Returns `nil` when the problem retires.
    public static func advance(
        _ state: ReviewState,
        grade: Grade,
        solvedAt: Date,
        calendar: Calendar
    ) -> ReviewState? {
        let stage: Int
        let lapses: Int

        switch grade {
        case .easy:
            stage = state.stage + 1
            lapses = state.lapses
            if stage >= intervals.count { return nil }
        case .hard:
            stage = state.stage
            lapses = state.lapses
        case .failed:
            stage = 0
            lapses = state.lapses + 1
        }

        return ReviewState(
            slug: state.slug,
            stage: stage,
            dueDate: DayWindow.addingDays(intervals[stage], to: solvedAt, calendar: calendar),
            lastSolvedAt: solvedAt,
            lapses: lapses
        )
    }
}
