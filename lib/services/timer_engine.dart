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
      _index++;
      _endsAt = DateTime.now().add(Duration(seconds: current.seconds));
      _paused = false;
      HapticFeedback.heavyImpact();
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
      HapticFeedback.heavyImpact();
      _syncLive();
    }
    notifyListeners();
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
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
