import Foundation

public enum Difficulty: String, Codable, Sendable, Equatable {
    case easy, medium, hard
}

/// One submission as recorded by LeetCode. Submission-level, not problem-level:
/// re-solving the same problem produces another `Submission`.
public struct Submission: Equatable, Sendable {
    public let slug: String
    public let submittedAt: Date
    public let status: String
    public let lang: String

    public init(slug: String, submittedAt: Date, status: String, lang: String) {
        self.slug = slug
        self.submittedAt = submittedAt
        self.status = status
        self.lang = lang
    }

    public var isAccepted: Bool { status == "Accepted" }
}

/// An entry in the static curriculum list.
public struct SeedProblem: Equatable, Sendable, Codable {
    public let slug: String
    public let title: String
    public let difficulty: Difficulty
    public let pattern: String
    public let seq: Int

    public init(slug: String, title: String, difficulty: Difficulty, pattern: String, seq: Int) {
        self.slug = slug
        self.title = title
        self.difficulty = difficulty
        self.pattern = pattern
        self.seq = seq
    }
}

/// Self-reported quality of a re-solve. Tunes scheduling only; never gates access.
public enum Grade: String, Sendable, Equatable {
    case easy, hard, failed
}

/// Spaced-repetition position for one problem.
public struct ReviewState: Equatable, Sendable {
    public let slug: String
    /// Index into `ReviewScheduler.intervals`.
    public var stage: Int
    public var dueDate: Date
    public var lastSolvedAt: Date
    public var lapses: Int

    public init(slug: String, stage: Int, dueDate: Date, lastSolvedAt: Date, lapses: Int) {
        self.slug = slug
        self.stage = stage
        self.dueDate = dueDate
        self.lastSolvedAt = lastSolvedAt
        self.lapses = lapses
    }
}

/// What a given day requires.
public struct DayPlan: Equatable, Sendable {
    public let newSlug: String?
    public let reviewSlugs: [String]
    /// Reviews that were due but pushed past the daily cap.
    public let deferredReviewSlugs: [String]

    public init(newSlug: String?, reviewSlugs: [String], deferredReviewSlugs: [String]) {
        self.newSlug = newSlug
        self.reviewSlugs = reviewSlugs
        self.deferredReviewSlugs = deferredReviewSlugs
    }
}

/// What remains unsatisfied right now.
public struct Outstanding: Equatable, Sendable {
    public let newSlug: String?
    public let reviewSlugs: [String]

    public init(newSlug: String?, reviewSlugs: [String]) {
        self.newSlug = newSlug
        self.reviewSlugs = reviewSlugs
    }

    public var isEmpty: Bool { newSlug == nil && reviewSlugs.isEmpty }
}

public enum UnlockReason: Equatable, Sendable {
    case quotaMet
    case override(expiresAt: Date)
    /// An internal fault. Enforcement stops so that a bug cannot brick the machine.
    case systemFault(String)
}

public enum GateState: Equatable, Sendable {
    case unlocked(UnlockReason)
    case locked(Outstanding)

    public var isLocked: Bool {
        if case .locked = self { return true }
        return false
    }
}
