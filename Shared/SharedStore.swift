import Foundation

nonisolated enum SharedStore {
    static let appGroupID = "group.com.serendipitynz.ClaudeUsage"

    private static let snapshotKey = "usage_snapshot_v1"
    private static let cookieKey = "claude_session_cookie"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func saveSnapshot(_ snapshot: UsageSnapshot) {
        guard let defaults else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    static func loadSnapshot() -> UsageSnapshot? {
        guard let defaults, let data = defaults.data(forKey: snapshotKey) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(UsageSnapshot.self, from: data)
    }

    static func saveCookie(_ cookie: String) {
        defaults?.set(cookie, forKey: cookieKey)
    }

    static func loadCookie() -> String? {
        defaults?.string(forKey: cookieKey)
    }

    static func clearCookie() {
        defaults?.removeObject(forKey: cookieKey)
    }
}
