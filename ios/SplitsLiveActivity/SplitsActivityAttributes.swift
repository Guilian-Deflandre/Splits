//
//  SplitsActivityAttributes.swift
//  SplitsLiveActivity
//

import ActivityKit
import Foundation

/// Shared by the Runner app (starts/updates the activity) and the widget
/// extension (renders it), so this file is a member of both targets.
/// Mirrors the map sent by TimerEngine._syncLive() on the Dart side.
@available(iOS 16.1, *)
struct SplitsActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var phase: String
        var title: String
        var detail: String
        var next: String
        var endsAt: Date
        var paused: Bool
        var remainingSec: Int
        var step: Int
        var steps: Int
    }
}
