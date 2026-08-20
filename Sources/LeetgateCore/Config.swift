import Foundation

/// Runtime configuration. Lives at `/Library/Application Support/leetgate/config.json`,
/// root-owned. Editing it and reloading the daemon is the supported way to change
/// the block lists — no recompile required.
public struct Config: Codable, Equatable, Sendable {
    public var username: String
    public var reviewCap: Int
    public var newProblemsPerDay: Int
    public var blockedBundleIDs: [String]
    public var blockedDomains: [String]

    public init(
        username: String,
        reviewCap: Int,
        newProblemsPerDay: Int,
        blockedBundleIDs: [String],
        blockedDomains: [String]
    ) {
        self.username = username
        self.reviewCap = reviewCap
        self.newProblemsPerDay = newProblemsPerDay
        self.blockedBundleIDs = blockedBundleIDs
        self.blockedDomains = blockedDomains
    }

    public static let `default` = Config(
        username: "lmack03",
        reviewCap: 5,
        newProblemsPerDay: 1,
        blockedBundleIDs: [
            "com.anthropic.claudefordesktop",
            "com.valvesoftware.steam",
            "com.netflix.Netflix",
            "com.spotify.client",
        ],
        // Editors, terminals and browsers are absent by design: client work is
        // never gated, and the terminal must stay available to repair the daemon.
        blockedDomains: [
            "claude.ai",
            "api.anthropic.com",
            "youtube.com",
            "reddit.com",
            "x.com",
            "twitter.com",
            "instagram.com",
            "tiktok.com",
            "discord.com",
        ]
    )

    public static func load(from url: URL) throws -> Config {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    }
}
