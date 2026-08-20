import Foundation
import AppKit
import LeetgateCore

enum EnforcerError: Error {
    case hostsUnreadable(String)
    case hostsUnwritable(String)
}

/// The only privileged code in the project. Deliberately thin: it executes an
/// `EnforcementPlan` and makes no decisions of its own.
enum Enforcer {
    static let hostsPath = "/etc/hosts"

    static func runningBundleIDs() -> [String] {
        NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
    }

    static func apply(_ plan: EnforcementPlan, dryRun: Bool) throws {
        for bundleID in plan.bundleIDsToTerminate {
            if dryRun {
                print("would terminate: \(bundleID)")
            } else {
                terminate(bundleID: bundleID)
            }
        }

        let current: String
        do {
            current = try String(contentsOfFile: hostsPath, encoding: .utf8)
        } catch {
            throw EnforcerError.hostsUnreadable(String(describing: error))
        }

        let updated = HostsFile.splice(into: current, block: plan.hostsBlock)
        guard updated != current else { return }

        if dryRun {
            print("would rewrite \(hostsPath):")
            print(updated)
            return
        }

        do {
            try updated.write(toFile: hostsPath, atomically: true, encoding: .utf8)
        } catch {
            throw EnforcerError.hostsUnwritable(String(describing: error))
        }
        flushDNS()
    }

    private static func terminate(bundleID: String) {
        let matches = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !matches.isEmpty else { return }
        for app in matches { app.terminate() }
        Notifier.post(
            title: "leetgate",
            body: "\(bundleID) is blocked until today's problems are done."
        )
    }

    private static func flushDNS() {
        for command in [["/usr/bin/dscacheutil", "-flushcache"],
                        ["/usr/bin/killall", "-HUP", "mDNSResponder"]] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: command[0])
            process.arguments = Array(command.dropFirst())
            try? process.run()
            process.waitUntilExit()
        }
    }
}
