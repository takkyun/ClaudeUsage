import Foundation

nonisolated struct UsageSnapshot: Codable, Sendable, Equatable {
    var sessionUtilization: Double
    var sessionResetsAt: Date?
    var weeklyUtilization: Double
    var weeklyResetsAt: Date?
    var weeklySonnetUtilization: Double?
    var weeklySonnetResetsAt: Date?
    var fetchedAt: Date
    var errorMessage: String?

    static let placeholder = UsageSnapshot(
        sessionUtilization: 42,
        sessionResetsAt: Date().addingTimeInterval(3600 * 3),
        weeklyUtilization: 67,
        weeklyResetsAt: Date().addingTimeInterval(3600 * 24 * 5),
        weeklySonnetUtilization: 31,
        weeklySonnetResetsAt: Date().addingTimeInterval(3600 * 24 * 5),
        fetchedAt: Date(),
        errorMessage: nil
    )
}
