import SwiftUI

struct UsageView: View {
    @ObservedObject var manager: UsageManager
    @State private var cookieInput: String = ""
    @State private var showingCookie: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Claude Usage")
                .font(.headline)

            if let snap = manager.snapshot {
                UsageRow(
                    title: "Session (5h)",
                    utilization: snap.sessionUtilization,
                    resetsAt: snap.sessionResetsAt,
                    includeDateInReset: false
                )
                UsageRow(
                    title: "Weekly (7d)",
                    utilization: snap.weeklyUtilization,
                    resetsAt: snap.weeklyResetsAt,
                    includeDateInReset: true
                )
                if let sonnetUtil = snap.weeklySonnetUtilization {
                    UsageRow(
                        title: "Weekly Sonnet (7d)",
                        utilization: sonnetUtil,
                        resetsAt: snap.weeklySonnetResetsAt,
                        includeDateInReset: true
                    )
                }
                if let msg = snap.errorMessage {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                HStack {
                    Text("Updated \(formatTime(snap.fetchedAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await manager.refresh() }
                    } label: {
                        if manager.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Refresh").font(.caption)
                        }
                    }
                    .buttonStyle(.borderless)
                    .disabled(manager.isLoading)
                }
            } else {
                Text("Paste your Claude.ai session cookie to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            Divider()

            Button(
                showingCookie
                    ? "Hide Cookie Input"
                    : (manager.cookie.isEmpty ? "Set Session Cookie" : "Update Cookie")
            ) {
                if !showingCookie {
                    cookieInput = manager.cookie
                }
                showingCookie.toggle()
            }
            .buttonStyle(.borderless)
            .font(.caption)

            if showingCookie {
                cookieInputSection
            }

            HStack {
                Spacer()
                Button("Quit ClaudeUsage") { NSApp.terminate(nil) }
                    .buttonStyle(.borderless)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 340)
    }

    private var cookieInputSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paste the full cookie string from DevTools:")
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextEditor(text: $cookieInput)
                .frame(height: 80)
                .font(.system(size: 11, design: .monospaced))
                .border(Color.secondary.opacity(0.3))
            HStack {
                Button("Save & Fetch") {
                    manager.saveCookie(cookieInput)
                    showingCookie = false
                    Task { await manager.refresh() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(cookieInput.isEmpty)

                if !manager.cookie.isEmpty {
                    Button("Clear") {
                        manager.clearCookie()
                        cookieInput = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    private func formatTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

struct UsageRow: View {
    let title: String
    let utilization: Double
    let resetsAt: Date?
    var includeDateInReset: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                if let resetsAt {
                    Text("Resets \(formatResetTime(resetsAt))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: min(utilization / 100, 1.0))
                .tint(color(for: utilization))
            Text("\(Int(utilization))% used")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func color(for util: Double) -> Color {
        if util < 70 { return .green }
        else if util < 90 { return .orange }
        else { return .red }
    }

    private func formatResetTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        if includeDateInReset {
            fmt.dateFormat = "d MMM 'at' h:mm a"
            return "on \(fmt.string(from: date))"
        } else {
            fmt.timeStyle = .short
            return "at \(fmt.string(from: date))"
        }
    }
}
