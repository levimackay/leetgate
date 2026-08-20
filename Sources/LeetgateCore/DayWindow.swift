import Foundation

/// Local-time day arithmetic. Every day boundary in leetgate goes through here
/// so that DST transitions and timezone changes are handled by `Calendar`
/// rather than by arithmetic on epoch seconds.
public enum DayWindow {
    /// The half-open interval `[start, end)` of the local day containing `instant`.
    public static func bounds(containing instant: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: instant)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }

    /// Whether `instant` falls on the same local day as `day`.
    public static func contains(_ instant: Date, on day: Date, calendar: Calendar) -> Bool {
        let (start, end) = bounds(containing: day, calendar: calendar)
        return instant >= start && instant < end
    }

    /// `count` calendar days after `instant`, preserving wall-clock time across DST.
    public static func addingDays(_ count: Int, to instant: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: count, to: instant)!
    }
}
