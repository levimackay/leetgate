# leetgate — design

**Date:** 2026-08-19
**Status:** approved design, pre-implementation

## Problem

Self-directed interview practice fails in two distinct ways, and they compound:

1. **Frequency.** Practice happens in sporadic bursts separated by weeks rather than on a schedule, so nothing accumulates and each session restarts from cold.
2. **Method.** Reading a solution and typing it out builds recognition, not production, and only production is tested under interview conditions.

The second failure is invisible to every metric a practice tracker normally records. A transcribed solution and a derived one produce the same artifact: one accepted submission. Acceptance count, streak, and difficulty mix cannot tell them apart.

leetgate addresses the first failure by making the machine unusable until the day's work is done, and the second by making the unit of work a *re-solve from memory* rather than an accepted submission. A solution that was copied cannot be reproduced cold a week later, so the schedule surfaces it without needing to detect anything.

Baseline metrics are read from the LeetCode API at install time. All submission history predating installation is ignored, so prior activity neither satisfies a quota nor inflates a statistic.

## Non-goals

- Not a problem-tracking or notes app. `leetcoach` already occupies that space and is untouched by this.
- Not a curriculum authoring tool. The problem list is a static seed.
- Not a general-purpose focus/blocker app. One trigger condition, one quota.

## Source of truth

LeetCode's public GraphQL endpoint at `https://leetcode.com/graphql`. No authentication, no scraping, no credentials stored. Verified working 2026-08-19.

Three queries carry the system:

| Query | Returns | Used for |
| --- | --- | --- |
| `recentSubmissionList(username, limit)` | every submission with `titleSlug`, `timestamp`, `statusDisplay`, `lang` | primary — submission-level, so repeat solves of one problem are distinguishable |
| `recentAcSubmissionList(username, limit)` | accepted only | cross-check |
| `matchedUser.submitStats` | lifetime counts by difficulty | stats display, drift detection |

Username is config, defaulting to `lmack03`.

**Open verification item, blocking on day one of implementation:** confirm that re-solving an already-solved problem produces a *new* row in `recentSubmissionList` rather than updating an existing one. The spaced-repetition half of this design depends on it. `statusDisplay` being per-submission strongly implies per-submission rows, but this must be confirmed against the real account by submitting the same problem twice and diffing the response. If it does not hold, fall back to per-problem submission-detail queries before building anything else.

## The daily gate

**Requirement to unlock = 1 new problem + every review due today.**

- New problem: the next unsolved entry in the seed list, in order.
- Reviews: any problem whose `due_date <= today`.
- Reviews are capped at **5 per day**; overflow rolls to tomorrow. Without this cap, three missed days build a wall that guarantees the override gets used, and a system whose escape hatch is routine is not a system.
- Ramp: fixed at 1 new problem per day. Steady state lands near 3–4 problems/day once reviews accumulate.

A requirement item is satisfied when an **accepted** submission for that `titleSlug` exists with a timestamp inside today's local-time window.

### Review scheduling

v1 uses fixed intervals, not full SM-2: **1d → 3d → 7d → 21d → 60d → retired.**

After a re-solve, the user grades it via `leetgate grade <slug> easy|hard|failed`:

- `easy` — advance one interval
- `hard` — repeat the current interval
- `failed` — reset to 1d

The grade gates nothing. Unlocking is driven entirely by the accepted submission, so there is no incentive to grade dishonestly. This is deliberate: a self-reported field that controls access would be gamed; a self-reported field that only tunes scheduling will be answered truthfully.

### Why the re-solve is the anti-copy mechanism

The API exposes enough to detect transcription heuristically — a first-try acceptance minutes after a problem is first opened, on an account with no failure history. **The design deliberately does not gate on this.** As skill improves, legitimate first-try acceptances become common, and an app that accuses the user of cheating when they genuinely solved something is an app that gets uninstalled.

Instead, the day-7 re-solve validates without judgment: a transcribed solution cannot be reproduced cold a week later, so it fails the check and resets. No heuristic, no false positives, no accusation.

The acceptance-rate signal is surfaced as a **statistic, not a gate**. `leetgate status` displays lifetime first-try rate and flags an implausibly high one.

## Enforcement

### Block list

**Applications** (terminated by bundle ID on launch, with a notification explaining why):

- `com.anthropic.claudefordesktop`
- `com.valvesoftware.steam`, `com.netflix.Netflix`, `com.spotify.client`

The application and domain lists live in a committed config file, so adding an entry is an edit and a daemon reload, not a code change.

**Domains** (nulled in `/etc/hosts` inside a marker-delimited block):

- `claude.ai`, `api.anthropic.com`
- `youtube.com`, `reddit.com`, `x.com`, `twitter.com`, `instagram.com`, `tiktok.com`
- `discord.com`

**Explicitly never blocked:**

- **Cursor and VS Code** — client work is never gated behind practice. A paid-work emergency must never require the override.
- **Terminal** — required to repair the daemon when it misbehaves.
- **The browser itself** — required to reach leetcode.com. Only specific domains are blocked, never the browser.
- `leetcode.com` — permanently allow-listed.

Blocking `api.anthropic.com` also disables Claude Code. This is intended and worth stating plainly: once installed, leetgate gates development on leetgate itself. Do the day's problem first.

### Schedule

Blocked from wake. Nothing unlocks until the quota is met. There is no grace window.

### Mechanism

- `/Library/LaunchDaemons/com.levimackay.leetgate.plist`, `RunAtLoad`, `KeepAlive` — killing the daemon respawns it.
- 60-second tick: evaluate state, enforce, sync if due.
- Hosts edits are confined between `# BEGIN LEETGATE` / `# END LEETGATE` markers, never touching the rest of the file, followed by `dscacheutil -flushcache; killall -HUP mDNSResponder`.
- Binary at `/usr/local/libexec/leetgate`, config and DB root-owned.

### Network failure fails closed

If the LeetCode API is unreachable, the system stays locked. Failing open would mean toggling wifi unlocks the machine. Being offline also means practice is impossible, so this costs nothing real. If the last successful sync is more than 2 hours stale while locked, a notification fires so a genuine outage is distinguishable from a bug.

### Anti-tamper, proportionate

`KeepAlive` respawn, `sudo`-gated `launchctl bootout`, root-owned config and database. That is the whole of it. No immutable flags, no watchdog-watching-the-watchdog. The goal is to outlast an impulse, not to make the machine unrecoverable.

### Escape hatch

```
sudo leetgate override --hours 24 --reason "<text>"
```

Disables enforcement for 24 hours, writes a row to `overrides`, and appears in `leetgate status` with its reason. `sudo leetgate uninstall` removes the daemon, the hosts block, and the plist. Both are documented in the README.

## Architecture

Swift, single binary, no runtime dependencies.

Swift rather than Python or Node specifically because **a root daemon must not depend on `/opt/homebrew`** — that path is user-writable, so a root process loading a Homebrew interpreter is a privilege-escalation hole. Swift also gives native `NSRunningApplication` for reliable bundle-ID matching and termination, and native notifications.

| Unit | Context | Responsibility | Depends on |
| --- | --- | --- | --- |
| `LeetgateCore` | library | scheduler, quota evaluator, hosts-block rendering, DB access | SQLite only |
| `LeetgateSync` | library | GraphQL client, submission ingest | URLSession, Core |
| `leetgated` | root daemon | tick loop, app termination, hosts enforcement, notifications | Core, Sync |
| `leetgate` | user CLI | `status`, `today`, `grade`, `override`, `install`, `uninstall` | Core |

`LeetgateCore` takes no root and no network, so quota evaluation, interval scheduling, and hosts rendering are all unit-testable as pure functions. The enforcement layer is the only part that needs privilege, and it stays thin.

### Data

SQLite at `/Library/Application Support/leetgate/leetgate.db`, root-owned, mode `0644` — daemon writes, CLI reads. No secrets stored.

Because the database is root-owned and the CLI runs unprivileged, `leetgate grade` cannot write to it directly. Grades are appended to a user-owned queue at `~/.leetgate/grades.jsonl`, which the daemon drains and deletes on each tick. This is safe precisely because grades gate nothing — tampering with the queue changes only the review schedule, never access, so the file needs no protection.

```
problems(slug PK, title, difficulty, pattern, seq)
submissions(id PK, slug, submitted_at, status, lang)
reviews(slug PK, stage, due_date, last_solved_at, lapses)
days(date PK, new_slug, reviews_required, satisfied_at)
overrides(id PK, started_at, expires_at, reason)
sync_state(id PK, last_success_at, last_error)
```

`problems` is seeded from a static list committed to the repo: NeetCode 150 order, Easy only for v1, Medium unlocked manually, Hard excluded. The seed starts at the beginning of the list; the first new problem is `two-sum`, solved cold.

### Data flow

```
leetcode.com/graphql --> LeetgateSync --> submissions table
                                              |
                             LeetgateCore.evaluate(today)
                                              |
                              locked / unlocked + reason
                                     /              \
                          leetgated enforce      leetgate status
                       (kill apps, /etc/hosts)     (CLI output)
```

### Error handling

| Condition | Behavior |
| --- | --- |
| API unreachable | stay locked, retain last known state, notify if >2h stale |
| API schema change (missing field) | stay locked, log loudly, notify — never silently unlock |
| DB corrupt or missing | daemon refuses to enforce, notifies; fail-safe unlocked, since a broken database must not brick the machine |
| Hosts file lacks markers | rewrite block from scratch, never touch content outside markers |
| Clock changes / DST | all day boundaries computed in local time via `Calendar`, never by dividing epoch seconds |

Note the deliberate asymmetry: network failure fails **closed**, internal corruption fails **open**. Network failure is expected and cheap to sit through; a corrupt database is a bug in this system and must not hold the machine hostage.

### Testing

- `LeetgateCore` — unit tests for interval progression, quota evaluation across day boundaries, review-cap overflow, hosts rendering including the no-markers and foreign-content cases.
- `LeetgateSync` — tests against recorded API fixtures, including a schema-change fixture that must fail closed.
- `leetgated` — `--dry-run` prints what it would terminate and what hosts lines it would write, without doing either. Enforcement itself is verified manually against the dry-run output before first install.

## Build order

**v1 — working system.** Daemon, hosts and app blocking, API sync, fixed-interval reviews, CLI with `status`/`today`/`grade`/`override`/`install`/`uninstall`, seeded Easy list.

**v2 — after v1 has been lived with for a few weeks.** Menu-bar app, real SM-2 with automatic grading derived from failed-attempt counts, pattern-mastery gating, Medium unlock, historical stats.

Nothing in v2 is built until v1 has survived actual use.

## Risks

| Risk | Mitigation |
| --- | --- |
| Re-solves may not appear as distinct API rows | verified on day one before anything else is built |
| Blocked from wake proves too aggressive and the override becomes routine | override usage is logged and visible; a pattern of use is the signal to move to a morning-grace window |
| Root daemon bug renders the machine unusable | Terminal and editors never blocked; internal failures fail open; documented `sudo` uninstall |
| LeetCode changes or removes the public GraphQL fields | schema-change fixture test; failure is loud and fails closed rather than silently unlocking |
