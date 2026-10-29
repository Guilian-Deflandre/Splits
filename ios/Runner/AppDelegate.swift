import ActivityKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let registrar = registrar(forPlugin: "SplitsLiveActivity") {
      let channel = FlutterMethodChannel(
        name: "splits/live_activity", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard #available(iOS 16.2, *) else {
          result(false)
          return
        }
        LiveActivityController.shared.handle(call, result: result)
      }
    }

    // A fresh launch means no workout is running: clear any activity left
    // behind by a previous run that was killed.
    if #available(iOS 16.2, *) {
      Task { await LiveActivityController.shared.endAll() }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func applicationWillTerminate(_ application: UIApplication) {
    // Best effort: iOS only calls this when the app is killed while still
    // running (not when already suspended), and gives it very little time.
    if #available(iOS 16.2, *) {
      let done = DispatchSemaphore(value: 0)
      // High priority limits the inversion of the main thread waiting on it.
      Task.detached(priority: .high) {
        await LiveActivityController.shared.endAll()
        done.signal()
      }
      _ = done.wait(timeout: .now() + 2)
    }
    super.applicationWillTerminate(application)
  }
}

/// Starts, updates and ends the workout Live Activity with local updates only
/// (pushType nil), so it works without the Push Notifications entitlement.
@available(iOS 16.2, *)
final class LiveActivityController {
  static let shared = LiveActivityController()

  private var activity: Activity<SplitsActivityAttributes>?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isEnabled":
      result(ActivityAuthorizationInfo().areActivitiesEnabled)
    case "startOrUpdate":
      guard let args = call.arguments as? [String: Any],
        let state = SplitsActivityAttributes.ContentState(args)
      else {
        result(FlutterError(code: "BAD_ARGS", message: "Invalid Live Activity data", details: nil))
        return
      }
      let staleDate = (args["workoutEndsAtMs"] as? Int).map {
        Date(timeIntervalSince1970: Double($0) / 1000)
      }
      Task {
        do {
          try await self.startOrUpdate(state, staleDate: staleDate)
          result(nil)
        } catch {
          result(FlutterError(
            code: "LIVE_ACTIVITY_ERROR", message: error.localizedDescription, details: "\(error)"))
        }
      }
    case "end":
      Task {
        await self.endAll()
        result(nil)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startOrUpdate(
    _ state: SplitsActivityAttributes.ContentState, staleDate: Date?
  ) async throws {
    let content = ActivityContent(state: state, staleDate: staleDate)
    if let activity, activity.activityState == .active {
      await activity.update(content)
      return
    }
    // Clear leftovers, e.g. from a run the app was killed during.
    await endAll()
    activity = try Activity.request(
      attributes: SplitsActivityAttributes(), content: content, pushType: nil)
  }

  func endAll() async {
    for existing in Activity<SplitsActivityAttributes>.activities {
      await existing.end(nil, dismissalPolicy: .immediate)
    }
    activity = nil
  }
}

@available(iOS 16.1, *)
extension SplitsActivityAttributes.ContentState {
  init?(_ map: [String: Any]) {
    guard let endsAtMs = map["endsAtMs"] as? Int else { return nil }
    self.init(
      phase: map["phase"] as? String ?? "work",
      title: map["title"] as? String ?? "Splits",
      detail: map["detail"] as? String ?? "",
      next: map["next"] as? String ?? "",
      endsAt: Date(timeIntervalSince1970: Double(endsAtMs) / 1000),
      paused: map["paused"] as? Bool ?? false,
      remainingSec: map["remainingSec"] as? Int ?? 0,
      step: map["step"] as? Int ?? 0,
      steps: map["steps"] as? Int ?? 0)
  }
}
