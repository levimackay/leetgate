import Foundation

/// Renders and splices leetgate's section of `/etc/hosts`.
///
/// Everything outside the markers is treated as untouchable — the file may
/// contain hand-written entries this project knows nothing about.
public enum HostsFile {
    public static let beginMarker = "# BEGIN LEETGATE"
    public static let endMarker = "# END LEETGATE"

    /// Domains that must never be blocked regardless of configuration.
    public static let neverBlock: Set<String> = ["leetcode.com"]

    /// A complete marker-delimited block for `domains`.
    public static func render(domains: [String]) -> String {
        let lines = domains
            .filter { !neverBlock.contains($0) }
            .flatMap { ["0.0.0.0 \($0)", "0.0.0.0 www.\($0)"] }
        return ([beginMarker] + lines + [endMarker]).joined(separator: "\n")
    }

    /// Replace leetgate's section of `contents` with `block`.
    /// Passing `nil` removes the section. Content outside the markers is preserved.
    public static func splice(into contents: String, block: String?) -> String {
        let stripped = removeBlock(from: contents)

        guard let block else { return stripped }

        let base = stripped.hasSuffix("\n") ? stripped : stripped + "\n"
        return base + block + "\n"
    }

    private static func removeBlock(from contents: String) -> String {
        guard let beginRange = contents.range(of: beginMarker),
              let endRange = contents.range(of: endMarker, range: beginRange.lowerBound..<contents.endIndex)
        else { return contents }

        var lower = beginRange.lowerBound
        var upper = endRange.upperBound

        // Absorb the newline immediately after the end marker, and the one before
        // the begin marker, so repeated splices do not accumulate blank lines.
        if upper < contents.endIndex, contents[upper] == "\n" {
            upper = contents.index(after: upper)
        }
        if lower > contents.startIndex {
            let before = contents.index(before: lower)
            if contents[before] == "\n" { lower = before }
        }

        var result = contents
        result.removeSubrange(lower..<upper)
        return result
    }
}
