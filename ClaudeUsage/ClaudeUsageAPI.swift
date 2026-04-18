import Foundation

enum ClaudeUsageAPIError: Error, LocalizedError {
    case emptyCookie
    case missingOrgId
    case httpError(Int)
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .emptyCookie: return "Cookie not set"
        case .missingOrgId: return "Could not resolve org ID"
        case .httpError(let code): return "HTTP \(code)"
        case .invalidResponse: return "Invalid response"
        case .decodingFailed: return "Failed to decode response"
        }
    }
}

enum ClaudeUsageAPI {
    nonisolated static func fetchOrganizationId(cookie: String) async throws -> String {
        for part in cookie.components(separatedBy: ";") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("lastActiveOrg=") {
                return String(trimmed.dropFirst("lastActiveOrg=".count))
            }
        }

        guard let url = URL(string: "https://claude.ai/api/bootstrap") else {
            throw ClaudeUsageAPIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.setValue("sessionKey=\(cookie)", forHTTPHeaderField: "Cookie")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let account = json["account"] as? [String: Any],
              let orgId = account["lastActiveOrgId"] as? String
        else {
            throw ClaudeUsageAPIError.missingOrgId
        }
        return orgId
    }

    nonisolated static func fetchUsage(cookie: String, orgId: String) async throws -> UsageSnapshot {
        guard let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage") else {
            throw ClaudeUsageAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("claude.ai", forHTTPHeaderField: "authority")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeUsageAPIError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw ClaudeUsageAPIError.httpError(http.statusCode)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeUsageAPIError.decodingFailed
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        func parseBucket(_ dict: [String: Any]?) -> (util: Double, resetsAt: Date?) {
            guard let dict else { return (0, nil) }
            let util = (dict["utilization"] as? Double) ?? 0
            let resets: Date?
            if let s = dict["resets_at"] as? String {
                resets = formatter.date(from: s)
            } else {
                resets = nil
            }
            return (util, resets)
        }

        let session = parseBucket(json["five_hour"] as? [String: Any])
        let weekly = parseBucket(json["seven_day"] as? [String: Any])
        let sonnetDict = json["seven_day_sonnet"] as? [String: Any]
        let sonnet: (util: Double, resetsAt: Date?)? = sonnetDict.map { parseBucket($0) }

        return UsageSnapshot(
            sessionUtilization: session.util,
            sessionResetsAt: session.resetsAt,
            weeklyUtilization: weekly.util,
            weeklyResetsAt: weekly.resetsAt,
            weeklySonnetUtilization: sonnet?.util,
            weeklySonnetResetsAt: sonnet?.resetsAt,
            fetchedAt: Date(),
            errorMessage: nil
        )
    }
}
