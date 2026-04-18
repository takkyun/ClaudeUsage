import Foundation
import Combine
import WidgetKit

@MainActor
final class UsageManager: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var isLoading = false
    @Published var cookie: String

    var onSnapshotUpdate: (() -> Void)?

    init() {
        self.cookie = SharedStore.loadCookie() ?? ""
        self.snapshot = SharedStore.loadSnapshot()
    }

    func saveCookie(_ newCookie: String) {
        cookie = newCookie
        SharedStore.saveCookie(newCookie)
    }

    func clearCookie() {
        cookie = ""
        SharedStore.clearCookie()
    }

    func refresh() async {
        guard !cookie.isEmpty else {
            applySnapshot(errorSnapshot(message: "Cookie not set"))
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let orgId = try await ClaudeUsageAPI.fetchOrganizationId(cookie: cookie)
            let fresh = try await ClaudeUsageAPI.fetchUsage(cookie: cookie, orgId: orgId)
            applySnapshot(fresh)
        } catch {
            applySnapshot(errorSnapshot(message: error.localizedDescription))
        }
    }

    private func applySnapshot(_ new: UsageSnapshot) {
        snapshot = new
        SharedStore.saveSnapshot(new)
        onSnapshotUpdate?()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func errorSnapshot(message: String) -> UsageSnapshot {
        UsageSnapshot(
            sessionUtilization: snapshot?.sessionUtilization ?? 0,
            sessionResetsAt: snapshot?.sessionResetsAt,
            weeklyUtilization: snapshot?.weeklyUtilization ?? 0,
            weeklyResetsAt: snapshot?.weeklyResetsAt,
            weeklySonnetUtilization: snapshot?.weeklySonnetUtilization,
            weeklySonnetResetsAt: snapshot?.weeklySonnetResetsAt,
            fetchedAt: Date(),
            errorMessage: message
        )
    }
}
