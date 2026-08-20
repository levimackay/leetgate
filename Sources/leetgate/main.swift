import Foundation
import LeetgateCore

let supportDirectory = "/Library/Application Support/leetgate"
let databasePath = "\(supportDirectory)/leetgate.db"
let configPath = "\(supportDirectory)/config.json"
let gradeQueuePath = "\(NSHomeDirectory())/.leetgate/grades.jsonl"

let config = (try? Config.load(from: URL(fileURLWithPath: configPath))) ?? .default
let calendar = Calendar.current
let arguments = Array(CommandLine.arguments.dropFirst())

func openDatabase() -> Database? {
    guard let db = try? Database(path: databasePath) else { return nil }
    try? db.migrate()
    return db
}

func title(for slug: String) -> String {
    Seed.problems.first { $0.slug == slug }?.title ?? slug
}

func url(for slug: String) -> String { "https://leetcode.com/problems/\(slug)/" }

func printStatus() {
    guard let db = openDatabase() else {
        print("leetgate: database unavailable — enforcement is off")
        return
    }

    let now = Date()
    let state = GateResolver.resolve(
        database: db, config: config, now: now, calendar: calendar, lastSyncSuccess: now
    )

    switch state {
    case .unlocked(.quotaMet):
        print("UNLOCKED — today's quota is met.")
    case .unlocked(.override(let expiresAt)):
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        print("UNLOCKED — override active until \(formatter.string(from: expiresAt)).")
    case .unlocked(.systemFault(let detail)):
        print("UNLOCKED — internal fault, enforcement disabled: \(detail)")
    case .locked(let outstanding):
        print("LOCKED")
        if let slug = outstanding.newSlug {
            print("  new:    \(title(for: slug))  \(url(for: slug))")
        }
        for slug in outstanding.reviewSlugs {
            print("  review: \(title(for: slug))  \(url(for: slug))")
        }
    }

    if let submissions = try? db.submissions(since: .distantPast), !submissions.isEmpty {
        let accepted = submissions.filter(\.isAccepted).count
        let rate = Double(accepted) / Double(submissions.count) * 100
        print(String(format: "\nfirst-try acceptance: %.0f%% over %d submissions", rate, submissions.count))
        if submissions.count >= 5 && rate == 100 {
            print("  ^ this number should not be this high. Solutions are being read, not derived.")
        }
    }
}

func printToday() {
    guard let db = openDatabase() else {
        // Before install there is no database; show the first assignment anyway.
        let plan = QuotaEvaluator.plan(
            seed: Seed.problems, solvedSlugs: [], reviews: [],
            today: Date(), calendar: calendar, reviewCap: config.reviewCap
        )
        if let slug = plan.newSlug {
            print("new:      \(title(for: slug))  \(url(for: slug))")
        }
        return
    }

    let now = Date()
    let installedAt = ((try? db.installedAt()) ?? nil) ?? now
    let submissions = (try? db.submissions(since: installedAt)) ?? []
    let (startOfToday, _) = DayWindow.bounds(containing: now, calendar: calendar)
    let solved = Set(
        submissions.filter { $0.isAccepted && $0.submittedAt < startOfToday }.map(\.slug)
    )

    let plan = QuotaEvaluator.plan(
        seed: Seed.problems,
        solvedSlugs: solved,
        reviews: (try? db.reviews()) ?? [],
        today: now,
        calendar: calendar,
        reviewCap: config.reviewCap
    )

    if let slug = plan.newSlug {
        print("new:      \(title(for: slug))  \(url(for: slug))")
    } else {
        print("new:      seed list complete")
    }
    for slug in plan.reviewSlugs {
        print("review:   \(title(for: slug))  \(url(for: slug))")
    }
    for slug in plan.deferredReviewSlugs {
        print("deferred: \(title(for: slug))")
    }
}

func queueGrade(slug: String, grade: Grade) {
    // The database is root-owned, so the CLI cannot write it. Grades queue here
    // and the daemon drains them. Safe because grades tune scheduling only and
    // never affect access — there is nothing to gain by forging one.
    let directory = (gradeQueuePath as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

    let line = #"{"slug":"\#(slug)","grade":"\#(grade.rawValue)"}"# + "\n"
    if let handle = FileHandle(forWritingAtPath: gradeQueuePath) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
    } else {
        try? line.write(toFile: gradeQueuePath, atomically: true, encoding: .utf8)
    }
    print("queued: \(slug) graded \(grade.rawValue)")
}

func recordOverride(hours: Int, reason: String) {
    guard getuid() == 0 else {
        print("override requires sudo: sudo leetgate override --hours \(hours) --reason \"\(reason)\"")
        exit(1)
    }
    guard let db = openDatabase() else {
        print("leetgate: database unavailable")
        exit(1)
    }
    let now = Date()
    try? db.recordOverride(
        expiresAt: now.addingTimeInterval(TimeInterval(hours) * 3600),
        reason: reason,
        now: now
    )
    print("override active for \(hours)h — logged as: \(reason)")
}

func value(after flag: String) -> String? {
    guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

switch arguments.first {
case "status", nil:
    printStatus()

case "today":
    printToday()

case "grade":
    guard arguments.count >= 3, let grade = Grade(rawValue: arguments[2]) else {
        print("usage: leetgate grade <slug> <easy|hard|failed>")
        exit(1)
    }
    queueGrade(slug: arguments[1], grade: grade)

case "override":
    let hours = value(after: "--hours").flatMap(Int.init) ?? 24
    guard let reason = value(after: "--reason") else {
        print("usage: sudo leetgate override --hours <n> --reason \"<why>\"")
        exit(1)
    }
    recordOverride(hours: hours, reason: reason)

default:
    print("""
    leetgate

      status                              current gate state
      today                               what today requires
      grade <slug> <easy|hard|failed>     grade a re-solve
      override --hours N --reason "..."   disable enforcement (requires sudo)
    """)
}
