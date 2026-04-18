import WidgetKit
import SwiftUI

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
}

struct UsageProvider: TimelineProvider {
    nonisolated func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: .placeholder)
    }

    nonisolated func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : (SharedStore.loadSnapshot() ?? .placeholder)
        completion(UsageEntry(date: Date(), snapshot: snapshot))
    }

    nonisolated func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let now = Date()
        let entry = UsageEntry(date: now, snapshot: SharedStore.loadSnapshot())
        let refreshAt = now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(refreshAt)))
    }
}

struct ClaudeUsageWidget: Widget {
    let kind: String = "ClaudeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageProvider()) { entry in
            ClaudeUsageWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Claude Usage")
        .description("Shows your current Claude.ai usage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ClaudeUsageWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: UsageEntry

    var body: some View {
        switch family {
        case .systemSmall:
            SmallUsageView(snapshot: entry.snapshot)
        default:
            MediumUsageView(snapshot: entry.snapshot)
        }
    }
}

private struct SmallUsageView: View {
    let snapshot: UsageSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Claude")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let snap = snapshot {
                Text("\(Int(snap.sessionUtilization))%")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(color(for: snap.sessionUtilization))
                Text("Session (5h)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let resets = snap.sessionResetsAt {
                    Text("Resets \(formatTime(resets))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                Text("–")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("Open app to sign in")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct MediumUsageView: View {
    let snapshot: UsageSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Claude Usage")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let snap = snapshot {
                MetricBar(title: "Session (5h)", utilization: snap.sessionUtilization)
                MetricBar(title: "Weekly (7d)", utilization: snap.weeklyUtilization)
                if let sonnet = snap.weeklySonnetUtilization {
                    MetricBar(title: "Weekly Sonnet", utilization: sonnet)
                }
                if let msg = snap.errorMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
            } else {
                Text("Open the app and paste your session cookie.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct MetricBar: View {
    let title: String
    let utilization: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.caption2)
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(color(for: utilization))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.35))
                    Capsule()
                        .fill(color(for: utilization))
                        .frame(width: geo.size.width * min(utilization / 100, 1.0))
                        .widgetAccentable()
                }
            }
            .frame(height: 8)
        }
    }
}

private func color(for util: Double) -> Color {
    if util < 70 { return .green }
    else if util < 90 { return .orange }
    else { return .red }
}

private func formatTime(_ date: Date) -> String {
    let fmt = DateFormatter()
    fmt.timeStyle = .short
    return fmt.string(from: date)
}
