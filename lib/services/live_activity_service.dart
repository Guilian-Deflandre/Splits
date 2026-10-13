import 'dart:io';
import 'package:live_activities/live_activities.dart';
import 'package:uuid/uuid.dart';

/// Thin wrapper over the `live_activities` plugin. No-ops off iOS or when the
/// user has disabled Live Activities.
///
/// [appGroupId] must match the App Group configured in Xcode and in the Swift
/// extension.
class LiveActivityService {
  static const appGroupId = 'group.com.example.splits';

  final _plugin = LiveActivities();
  String? _activityId;
  bool _ready = false;

  Future<void> init() async {
    if (!Platform.isIOS) return;
    await _plugin.init(appGroupId: appGroupId);
    _ready = await _plugin.areActivitiesEnabled();
  }

  Future<void> startOrUpdate(Map<String, dynamic> data) async {
    if (!_ready) return;
    if (_activityId == null) {
      _activityId = await _plugin.createActivity(const Uuid().v4(), data);
    } else {
      await _plugin.updateActivity(_activityId!, data);
    }
  }

  Future<void> end() async {
    if (!_ready || _activityId == null) return;
    final id = _activityId!;
    _activityId = null;
    await _plugin.endActivity(id);
  }
}
