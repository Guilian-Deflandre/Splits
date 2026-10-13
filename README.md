# Splits — interval timer with iOS Live Activity

Free splits-training app. A workout = optional warm-up, a list of blocks
(`reps × interval`, optional rest between reps), optional cool-down.
Example from the brief: 2×1 min, 3×2 min, 2×1 min.

## Structure
```
lib/models/workout.dart            Workout / IntervalBlock / Segment (+ flatten)
lib/services/timer_engine.dart     Timestamp-based timer, pause/skip/catch-up
lib/services/live_activity_service.dart   live_activities plugin wrapper
lib/services/workout_store.dart    JSON persistence (shared_preferences)
lib/screens/                       List, editor, run screen
ios_live_activity/SplitsLiveActivity.swift   Widget extension (SwiftUI)
```

## Setup
1. `flutter create --org com.yourname --project-name splits .` (generates ios/ etc.), then copy `lib/` and `pubspec.yaml` over the generated ones.
2. `flutter pub get`
3. Open `ios/Runner.xcworkspace` in Xcode:
   - Set iOS Deployment Target to **16.2+** (Runner and the extension).
   - Runner → Signing & Capabilities → **+ App Groups** → `group.com.example.splits` (use your own ID).
   - File → New → Target → **Widget Extension** (name `SplitsLiveActivity`, untick "Include Live Activity"/"Configuration Intent"). Delete the generated Swift files and add `ios_live_activity/SplitsLiveActivity.swift` to that target.
   - Add the same App Group to the extension target.
   - Runner `Info.plist`: add `NSSupportsLiveActivities` = `YES` (and optionally `NSSupportsLiveActivitiesFrequentUpdates` = `YES`).
4. Replace the group ID in **both** `live_activity_service.dart` and the Swift file.
5. Run on a real device (Live Activities need iOS 16.2+; Simulator support is limited).

## Known gaps (next steps)
- **Background updates**: the countdown on the lock screen ticks natively, but moving to the *next* segment is triggered from Dart. If iOS suspends the app, the Live Activity stays on the old segment until you return. Fix options: schedule local notifications at each boundary, run a silent background-audio session, or use push updates.
- Audio/voice cues, screen wake-lock, sound at segment change.
- Reorder blocks, duplicate workouts, history.
- Not compiled/tested yet — the sandbox has no Flutter SDK. Expect small fixes on first build.
