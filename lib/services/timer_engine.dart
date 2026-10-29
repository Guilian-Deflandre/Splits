import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/workout.dart';
import 'live_activity_service.dart';

/// Runs a flattened list of [Segment]s.
///
/// Time is derived from wall-clock timestamps (not tick counting), so it stays
/// correct if the app is suspended and resumed.
class TimerEngine extends ChangeNotifier {
  TimerEngine(this.segments, {this.live});

  final List<Segment> segments;
  final LiveActivityService? live;

  int _index = 0;
  DateTime _endsAt = DateTime.now();
  Duration _pausedRemaining = Duration.zero;
  bool _paused = false;
  bool _finished = false;
  Timer? _ticker;

  int get index => _index;
  bool get paused => _paused;
  bool get finished => _finished;
  Segment get current => segments[_index];
  Segment? get next =>
      _index + 1 < segments.length ? segments[_index + 1] : null;

  Duration get remaining {
    if (_finished) return Duration.zero;
    if (_paused) return _pausedRemaining;
    final d = _endsAt.difference(DateTime.now());
    return d.isNegative ? Duration.zero : d;
  }

  double get segmentProgress {
    final total = current.seconds * 1000;
    if (total == 0) return 1;
    return (1 - remaining.inMilliseconds / total).clamp(0.0, 1.0);
  }

  void start() {
    if (segments.isEmpty) {
      _finished = true;
      return;
    }
    _index = 0;
    _endsAt = DateTime.now().add(Duration(seconds: current.seconds));
    HapticFeedback.heavyImpact();
    _syncLive();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void pause() {
    if (_paused || _finished) return;
    _pausedRemaining = remaining;
    _paused = true;
    _syncLive();
    notifyListeners();
  }

  void resume() {
    if (!_paused || _finished) return;
    _endsAt = DateTime.now().add(_pausedRemaining);
    _paused = false;
    _syncLive();
    notifyListeners();
  }

  void skip() {
    if (_finished) return;
    if (_index + 1 >= segments.length) {
      _finish();
    } else {
      final from = current;
      _index++;
      _endsAt = DateTime.now().add(Duration(seconds: current.seconds));
      _paused = false;
      _buzzTransition(from, current);
      _syncLive();
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _ticker?.cancel();
    await live?.end();
  }

  void _tick() {
    if (_paused || _finished) return;
    final from = current;
    var changed = false;
    // Loop catches up if the app was suspended across segment boundaries.
    while (!_finished && !DateTime.now().isBefore(_endsAt)) {
      if (_index + 1 >= segments.length) {
        _finish();
        break;
      }
      _index++;
      _endsAt = _endsAt.add(Duration(seconds: current.seconds));
      changed = true;
    }
    if (changed && !_finished) {
      _buzzTransition(from, current);
      _syncLive();
    }
    notifyListeners();
  }

  /// Long vibrations on a segment change: 3 into/out of warm-up or cool-down,
  /// 2 between blocks, 1 between interval and rest.
  void _buzzTransition(Segment from, Segment to) {
    const edges = {SegmentType.warmup, SegmentType.cooldown};
    final times = edges.contains(from.type) || edges.contains(to.type)
        ? 3
        : from.block != to.block
            ? 2
            : 1;
    _buzz(times);
  }

  /// iOS only offers one fixed-length (~0.4 s) system vibration, so "longer"
  /// means using it instead of a tap, and patterns are repeats with a gap.
  static Future<void> _buzz(int times) async {
    for (var i = 0; i < times; i++) {
      if (i > 0) await Future.delayed(const Duration(milliseconds: 700));
      HapticFeedback.vibrate();
    }
  }

  void _finish() {
    _finished = true;
    _ticker?.cancel();
    HapticFeedback.vibrate();
    live?.end();
  }

  void _syncLive() {
    live?.startOrUpdate({
      'phase': current.type.name, // warmup | work | rest | cooldown
      'title': current.title,
      'detail': current.detail,
      'next': next == null ? 'Finish' : next!.title,
      'endsAtMs': _endsAt.millisecondsSinceEpoch,
      'paused': _paused,
      'remainingSec': (_paused ? _pausedRemaining : remaining).inSeconds,
      'step': _index + 1,
      'steps': segments.length,
      // Lets the Live Activity mark itself finished even if the app is
      // suspended or killed and can't end it. Unknown while paused.
      if (!_paused) 'workoutEndsAtMs': _workoutEndsAt.millisecondsSinceEpoch,
    });
  }

  DateTime get _workoutEndsAt => _endsAt.add(Duration(
      seconds: segments.skip(_index + 1).fold(0, (sum, s) => sum + s.seconds)));

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
