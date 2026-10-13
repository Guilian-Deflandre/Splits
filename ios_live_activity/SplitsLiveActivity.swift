import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Shared with the `live_activities` Flutter plugin (keep as-is)

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState
    public struct ContentState: Codable, Hashable {
        var appGroupId: String
    }
    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String { "\(id)_\(key)" }
}

// Must match LiveActivityService.appGroupId in Dart.
let sharedDefault = UserDefaults(suiteName: "group.com.example.splits")!

// MARK: - Data read from the map sent by Flutter

struct TimerState {
    let phase: String       // warmup | work | rest | cooldown
    let title: String
    let detail: String
    let next: String
    let endsAt: Date
    let paused: Bool
    let remainingSec: Int
    let step: Int
    let steps: Int

    init(_ a: LiveActivitiesAppAttributes) {
        func key(_ k: String) -> String { a.prefixedKey(k) }
        phase = sharedDefault.string(forKey: key("phase")) ?? "work"
        title = sharedDefault.string(forKey: key("title")) ?? ""
        detail = sharedDefault.string(forKey: key("detail")) ?? ""
        next = sharedDefault.string(forKey: key("next")) ?? ""
        endsAt = Date(timeIntervalSince1970:
            Double(sharedDefault.integer(forKey: key("endsAtMs"))) / 1000)
        paused = sharedDefault.bool(forKey: key("paused"))
        remainingSec = sharedDefault.integer(forKey: key("remainingSec"))
        step = sharedDefault.integer(forKey: key("step"))
        steps = sharedDefault.integer(forKey: key("steps"))
    }

    var color: Color {
        switch phase {
        case "work": return .green
        case "rest": return .orange
        case "warmup": return .blue
        default: return .teal
        }
    }
}

/// Counts down natively on the lock screen — no per-second updates needed.
struct CountdownText: View {
    let s: TimerState
    var body: some View {
        Group {
            if s.paused {
                Text(String(format: "%02d:%02d", s.remainingSec / 60, s.remainingSec % 60))
            } else {
                Text(s.endsAt, style: .timer)
            }
        }
        .monospacedDigit()
    }
}

// MARK: - Widget

struct SplitsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let s = TimerState(context.attributes)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s.title.uppercased())
                        .font(.headline).foregroundColor(s.color)
                    Text(s.detail).font(.caption)
                    Text("Next: \(s.next)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                CountdownText(s: s)
                    .font(.system(size: 44, weight: .light))
                    .multilineTextAlignment(.trailing)
            }
            .padding()
            .activityBackgroundTint(Color.black.opacity(0.8))
        } dynamicIsland: { context in
            let s = TimerState(context.attributes)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(s.title).font(.headline).foregroundColor(s.color)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(s: s).font(.title2)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(s.detail) · Next: \(s.next)").font(.caption)
                }
            } compactLeading: {
                Image(systemName: "figure.run").foregroundColor(s.color)
            } compactTrailing: {
                CountdownText(s: s).frame(width: 48)
            } minimal: {
                Image(systemName: "timer").foregroundColor(s.color)
            }
        }
    }
}

@main
struct SplitsWidgetBundle: WidgetBundle {
    var body: some Widget { SplitsLiveActivity() }
}
