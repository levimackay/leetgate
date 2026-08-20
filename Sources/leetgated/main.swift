import Foundation
import LeetgateCore
import LeetgateSync

let supportDirectory = "/Library/Application Support/leetgate"
let databasePath = "\(supportDirectory)/leetgate.db"
let configPath = "\(supportDirectory)/config.json"

/// The console user's grade queue. The daemon runs as root, so it reads the queue
/// out of the logged-in user's home directory rather than root's.
let consoleUser = ProcessInfo.processInfo.environment["SUDO_USER"] ?? NSUserName()
let gradeQueuePath = "\(NSHomeDirectoryForUser(consoleUser) ?? NSHomeDirectory())/.leetgate/grades.jsonl"

let arguments = Set(CommandLine.arguments.dropFirst())
let dryRun = arguments.contains("--dry-run")
let once = arguments.contains("--once")

let config = (try? Config.load(from: URL(fileURLWithPath: configPath))) ?? .default
let calendar = Calendar.current
let client = LeetCodeClient(transport: URLSessionTransport())

let database: Database
do {
    database = try Database(path: databasePath)
    try database.migrate()
} catch {
    // Cannot open the store: fail open and say so. A broken daemon must not
    // leave the machine locked.
    FileHandle.standardError.write(Data("leetgated: database unavailable: \(error)\n".utf8))
    try? Enforcer.apply(EnforcementPlan(bundleIDsToTerminate: [], hostsBlock: nil), dryRun: dryRun)
    exit(1)
}

if (try? database.installedAt()) ?? nil == nil {
    try? database.setInstalledAt(Date())
}

var lastSyncSuccess: Date?
var lastSyncAttempt: Date = .distantPast
var staleNotified = false

@MainActor func syncInterval(locked: Bool) -> TimeInterval { locked ? 120 : 900 }

@MainActor func drainGradeQueue() {
    guard let contents = try? String(contentsOfFile: gradeQueuePath, encoding: .utf8) else { return }
    let now = Date()

    for line in contents.split(separator: "\n") {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let slug = object["slug"],
              let raw = object["grade"],
              let grade = Grade(rawValue: raw)
        else { continue }

        guard let existing = (try? database.reviews())?.first(where: { $0.slug == slug }) else { continue }

        if let next = ReviewScheduler.advance(existing, grade: grade, solvedAt: now, calendar: calendar) {
            try? database.upsertReview(next)
        } else {
            try? database.deleteReview(slug: slug)
        }
    }

    try? FileManager.default.removeItem(atPath: gradeQueuePath)
}

/// Any problem accepted since install that has no review row yet starts its ladder.
@MainActor func openReviewsForNewSolves() {
    guard let installedAt = (try? database.installedAt()) ?? nil,
          let submissions = try? database.submissions(since: installedAt),
          let existing = try? database.reviews()
    else { return }

    let tracked = Set(existing.map(\.slug))

    for submission in submissions where submission.isAccepted && !tracked.contains(submission.slug) {
        let state = ReviewScheduler.start(
            slug: submission.slug, solvedAt: submission.submittedAt, calendar: calendar
        )
        try? database.upsertReview(state)
    }
}

@MainActor func tick() async {
    let now = Date()

    var state = GateResolver.resolve(
        database: database, config: config, now: now,
        calendar: calendar, lastSyncSuccess: lastSyncSuccess
    )

    if now.timeIntervalSince(lastSyncAttempt) >= syncInterval(locked: state.isLocked) {
        lastSyncAttempt = now
        do {
            let installedAt = ((try? database.installedAt()) ?? nil) ?? now
            // Fetch first, then persist: the await must not carry the database.
            let fetched = try await SubmissionIngest.fetch(client: client, config: config)
            try SubmissionIngest.store(fetched, database: database, installedAt: installedAt)
            lastSyncSuccess = Date()
            staleNotified = false
        } catch {
            FileHandle.standardError.write(Data("leetgated: sync failed: \(error)\n".utf8))
        }
    }

    drainGradeQueue()
    openReviewsForNewSolves()

    state = GateResolver.resolve(
        database: database, config: config, now: Date(),
        calendar: calendar, lastSyncSuccess: lastSyncSuccess
    )

    // Distinguish a genuine outage from a bug: say so, once.
    if state.isLocked, !staleNotified {
        let stale = lastSyncSuccess.map { Date().timeIntervalSince($0) > GateResolver.syncFreshness } ?? true
        if stale {
            Notifier.post(
                title: "leetgate",
                body: "Cannot reach LeetCode. Staying locked until sync succeeds."
            )
            staleNotified = true
        }
    }

    let plan = EnforcementPlan.for(
        state: state, config: config, runningBundleIDs: Enforcer.runningBundleIDs()
    )

    do {
        try Enforcer.apply(plan, dryRun: dryRun)
    } catch {
        FileHandle.standardError.write(Data("leetgated: enforcement failed: \(error)\n".utf8))
    }
}

if once {
    await tick()
    exit(0)
}

while true {
    await tick()
    try? await Task.sleep(for: .seconds(60))
}
