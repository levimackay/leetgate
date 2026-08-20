import Foundation

/// User-visible messages. An app vanishing with no explanation is indistinguishable
/// from a crash, so every termination says why.
enum Notifier {
    static func post(title: String, body: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "display notification \(quoted(body)) with title \(quoted(title))",
        ]
        try? process.run()
    }

    private static func quoted(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
