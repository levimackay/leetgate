# leetgate

Blocks a configured set of applications and websites on macOS until the day's
LeetCode quota is verified complete against LeetCode's public API.

The daily requirement is **one new problem plus every review due today**. A review
is a re-solve of a problem you have already done, scheduled at 1, 3, 7, 21 and 60
days. Nothing counts until an accepted submission for that problem appears on your
LeetCode profile with today's date.

The re-solve is the point. Reading a solution and typing it out builds recognition,
not production, and only production gets tested. A transcribed solution cannot be
reproduced cold a week later, so it fails its day-7 review and resets — no
heuristics, no accusations, just the ladder doing its job.

## Install

```bash
swift build -c release
sudo install -d "/Library/Application Support/leetgate"
sudo install -m 755 .build/release/leetgated /usr/local/libexec/leetgated
sudo install -m 755 .build/release/leetgate /usr/local/bin/leetgate
sudo install -m 644 Resources/com.levimackay.leetgate.plist /Library/LaunchDaemons/
sudo launchctl bootstrap system /Library/LaunchDaemons/com.levimackay.leetgate.plist
```

Only submissions made after installation count. History is not backfilled.

Before installing, dry-run it once and confirm `/etc/hosts` is untouched:

```bash
shasum /etc/hosts
sudo .build/debug/leetgated --dry-run --once
shasum /etc/hosts
```

## Use

```
leetgate today      what today requires, with links
leetgate status     locked or unlocked, and why
leetgate grade <slug> <easy|hard|failed>
```

Grade a re-solve honestly. The grade changes only when the problem comes back —
it has no effect on whether anything unlocks, so there is nothing to gain by lying.

## Escape hatch

```bash
sudo leetgate override --hours 24 --reason "why"
```

Logged and shown in `leetgate status`. If you find yourself using this weekly, the
schedule is wrong, not you — widen it rather than working around it.

## Uninstall

```bash
sudo launchctl bootout system/com.levimackay.leetgate
sudo rm /Library/LaunchDaemons/com.levimackay.leetgate.plist
sudo rm /usr/local/libexec/leetgated /usr/local/bin/leetgate
sudo /usr/bin/sed -i '' '/# BEGIN LEETGATE/,/# END LEETGATE/d' /etc/hosts
```

## What is never blocked

Editors, terminals, browsers, and `leetcode.com`. Client work is never gated, and
the terminal must stay available to repair the daemon.

`api.anthropic.com` **is** blocked, which disables Claude Code. That is intended.

## Failure behavior

- **Cannot reach LeetCode:** stays locked. Otherwise toggling wifi would unlock the
  machine, and being offline makes practice impossible anyway.
- **Database corrupt or unreadable:** stops enforcing. A bug in this program must
  not be able to hold the machine hostage.

## Configuration

`/Library/Application Support/leetgate/config.json` — block lists, username, review
cap. Edit, then `sudo launchctl kickstart -k system/com.levimackay.leetgate`.

## Development

```bash
swift test
```

All decision logic lives in `LeetgateCore` as pure functions over an injected clock
and calendar, so scheduling, quota evaluation and hosts rendering are testable
without root or network. The privileged code in `leetgated` executes plans and makes
no decisions of its own.
