//
//  SplitsLiveActivity.swift
//  SplitsLiveActivity
//
//  Created by Guilian Deflandre on 15/10/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

typealias SplitsState = SplitsActivityAttributes.ContentState

extension SplitsState {
    var color: Color {
        switch phase {
        case "work": return .green
        case "rest": return .blue
        default: return .orange
        }
    }

    var pausedText: String {
        String(format: "%d:%02d", remainingSec / 60, remainingSec % 60)
    }
}

/// Countdown that ticks on its own (no app updates needed) unless paused.
struct CountdownText: View {
    let state: SplitsState

    var body: some View {
        if state.paused || state.endsAt <= Date() {
            Text(state.pausedText)
        } else {
            Text(timerInterval: Date()...state.endsAt, countsDown: true)
        }
    }
}

struct SplitsLockScreenView: View {
    let state: SplitsState

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(state.color)
                if !state.detail.isEmpty {
                    Text(state.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text("Next: \(state.next) · \(state.step)/\(state.steps)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                CountdownText(state: state)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                if state.paused {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

/// Shown once the workout's end time has passed but the app (suspended or
/// killed) hasn't ended the activity yet.
struct FinishedView: View {
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Workout finished")
                .font(.headline)
        }
        .padding()
    }
}

struct SplitsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SplitsActivityAttributes.self) { context in
            Group {
                if context.isStale {
                    FinishedView()
                } else {
                    SplitsLockScreenView(state: context.state)
                }
            }
            .activityBackgroundTint(Color.black.opacity(0.8))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            if context.isStale {
                return DynamicIsland {
                    DynamicIslandExpandedRegion(.center) {
                        FinishedView()
                    }
                } compactLeading: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } compactTrailing: {
                    Text("Done")
                } minimal: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(state.title)
                        .font(.headline)
                        .foregroundStyle(state.color)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(state: state)
                        .font(.title2.bold())
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Next: \(state.next) · \(state.step)/\(state.steps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Circle()
                    .fill(state.color)
                    .frame(width: 10, height: 10)
            } compactTrailing: {
                CountdownText(state: state)
                    .monospacedDigit()
                    .frame(maxWidth: 48)
            } minimal: {
                Circle()
                    .fill(state.color)
                    .frame(width: 10, height: 10)
            }
        }
    }
}
