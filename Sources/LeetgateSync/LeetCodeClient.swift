import Foundation
import LeetgateCore

public enum SyncError: Error {
    case transport(String)
    case http(Int)
    /// The response did not have the expected shape. Callers must treat this as
    /// "unknown", never as "no submissions".
    case schema(String)
}

public protocol HTTPTransport: Sendable {
    func post(url: URL, body: Data, headers: [String: String]) async throws -> (Data, Int)
}

public struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func post(url: URL, body: Data, headers: [String: String]) async throws -> (Data, Int) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 20
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        return (data, status)
    }
}

/// Reads the public profile endpoint. No authentication, no cookies, no scraping.
public struct LeetCodeClient {
    public static let endpoint = URL(string: "https://leetcode.com/graphql")!

    private let transport: HTTPTransport

    public init(transport: HTTPTransport) {
        self.transport = transport
    }

    private struct Envelope: Decodable {
        struct Payload: Decodable {
            let recentSubmissionList: [Row]?
        }
        struct Row: Decodable {
            let titleSlug: String
            let timestamp: String
            let statusDisplay: String
            let lang: String
        }
        struct GraphQLError: Decodable {
            let message: String
        }
        let data: Payload?
        let errors: [GraphQLError]?
    }

    /// Every submission — accepted and failed — most recent first.
    public func recentSubmissions(username: String, limit: Int) async throws -> [Submission] {
        let query = """
        query recentSubmissions($username: String!, $limit: Int!) {
          recentSubmissionList(username: $username, limit: $limit) {
            titleSlug
            timestamp
            statusDisplay
            lang
          }
        }
        """
        let body = try JSONSerialization.data(withJSONObject: [
            "query": query,
            "variables": ["username": username, "limit": limit],
        ])

        let data: Data
        let status: Int
        do {
            (data, status) = try await transport.post(
                url: Self.endpoint,
                body: body,
                headers: [
                    "Content-Type": "application/json",
                    "Referer": "https://leetcode.com",
                    "User-Agent": "leetgate/1.0",
                ]
            )
        } catch {
            throw SyncError.transport(String(describing: error))
        }

        guard status == 200 else { throw SyncError.http(status) }

        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw SyncError.schema("undecodable response: \(error)")
        }

        if let errors = envelope.errors, !errors.isEmpty {
            throw SyncError.schema(errors.map(\.message).joined(separator: "; "))
        }

        guard let rows = envelope.data?.recentSubmissionList else {
            throw SyncError.schema("recentSubmissionList absent from response")
        }

        return try rows.map { row in
            guard let seconds = TimeInterval(row.timestamp) else {
                throw SyncError.schema("non-numeric timestamp: \(row.timestamp)")
            }
            return Submission(
                slug: row.titleSlug,
                submittedAt: Date(timeIntervalSince1970: seconds),
                status: row.statusDisplay,
                lang: row.lang
            )
        }
    }
}
