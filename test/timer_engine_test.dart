import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splits/models/workout.dart';
import 'package:splits/services/live_activity_service.dart';
import 'package:splits/services/timer_engine.dart';

/// Records what the engine sends to the Live Activity instead of calling iOS.
class FakeLive extends LiveActivityService {
  final updates = <Map<String, dynamic>>[];
  var ended = 0;

  @override
  Future<void> startOrUpdate(Map<String, dynamic> data) async =>
      updates.add(data);

  @override
  Future<void> end() async => ended++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // The engine triggers haptics; swallow those platform calls in tests.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
  });

  const segments = [
    Segment(SegmentType.work, 'A', '', 60),
    Segment(SegmentType.rest, 'B', '', 30),
  ];

  late TimerEngine engine;

  tearDown(() => engine.dispose());

  test('starts on the first segment', () {
    engine = TimerEngine(segments)..start();
    expect(engine.index, 0);
    expect(engine.remaining.inSeconds, greaterThan(58));
    expect(engine.finished, isFalse);
  });

  test('countdown shows exactly the segment duration when it starts', () {
    engine = TimerEngine(segments)..start();
    expect(engine.remainingSeconds, 60);
    engine.skip();
    expect(engine.remainingSeconds, 30);
  });

  test('skip moves to the next segment', () {
    engine = TimerEngine(segments)..start();
    engine.skip();
    expect(engine.index, 1);
    expect(engine.current.type, SegmentType.rest);
  });

  test('skipping the last segment finishes the workout', () {
    engine = TimerEngine(segments)..start();
    engine.skip();
    engine.skip();
    expect(engine.finished, isTrue);
  });

  test('pause freezes the remaining time and resume continues', () async {
    engine = TimerEngine(segments)..start();
    engine.pause();
    final frozen = engine.remaining;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(engine.remaining, frozen);
    expect(engine.paused, isTrue);
    engine.resume();
    expect(engine.paused, isFalse);
  });

  test('empty segment list finishes immediately', () {
    engine = TimerEngine(const [])..start();
    expect(engine.finished, isTrue);
  });

  group('transition vibrations', () {
    late int longVibrations;

    setUp(() {
      longVibrations = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        // Taps use the same method with a type argument; long ones have none.
        if (call.method == 'HapticFeedback.vibrate' && call.arguments == null) {
          longVibrations++;
        }
        return null;
      });
    });

    /// Starts on the first segment, skips to the second and returns how many
    /// long vibrations that transition produced.
    Future<int> vibrationsOnSkip(
        WidgetTester tester, List<Segment> segments) async {
      engine = TimerEngine(segments)..start();
      engine.skip();
      await tester.pump(const Duration(seconds: 3)); // let the gaps elapse
      await engine.stop(); // no pending timers when the test ends
      return longVibrations;
    }

    testWidgets('interval to rest in the same block: 1', (tester) async {
      expect(
          await vibrationsOnSkip(tester, const [
            Segment(SegmentType.work, 'A', '', 60, block: 0),
            Segment(SegmentType.rest, 'B', '', 30, block: 0),
          ]),
          1);
    });

    testWidgets('interval to interval in the same block: 1', (tester) async {
      expect(
          await vibrationsOnSkip(tester, const [
            Segment(SegmentType.work, 'A', '', 60, block: 0),
            Segment(SegmentType.work, 'B', '', 60, block: 0),
          ]),
          1);
    });

    testWidgets('into the next block: 2', (tester) async {
      expect(
          await vibrationsOnSkip(tester, const [
            Segment(SegmentType.rest, 'A', '', 30, block: 0),
            Segment(SegmentType.work, 'B', '', 60, block: 1),
          ]),
          2);
    });

    testWidgets('warm-up to first interval: 3', (tester) async {
      expect(
          await vibrationsOnSkip(tester, const [
            Segment(SegmentType.warmup, 'A', '', 300),
            Segment(SegmentType.work, 'B', '', 60, block: 0),
          ]),
          3);
    });

    testWidgets('last interval to cool-down: 3', (tester) async {
      expect(
          await vibrationsOnSkip(tester, const [
            Segment(SegmentType.work, 'A', '', 60, block: 0),
            Segment(SegmentType.cooldown, 'B', '', 300),
          ]),
          3);
    });
  });

  group('Live Activity data', () {
    late FakeLive live;

    setUp(() => live = FakeLive());

    test('running: same seconds as the screen, plus the workout end', () {
      engine = TimerEngine(segments, live: live)..start();
      final data = live.updates.last;
      expect(data['paused'], isFalse);
      expect(data['remainingSec'], engine.remainingSeconds);
      // Only the 30 s rest is left after the current segment.
      expect(data['workoutEndsAtMs'] - data['endsAtMs'], 30 * 1000);
    });

    test('paused: same seconds as the screen, no workout end', () {
      engine = TimerEngine(segments, live: live)..start();
      engine.pause();
      final data = live.updates.last;
      expect(data['paused'], isTrue);
      expect(data['remainingSec'], engine.remainingSeconds);
      expect(data.containsKey('workoutEndsAtMs'), isFalse);
    });

    test('after a skip: describes the new segment', () {
      engine = TimerEngine(segments, live: live)..start();
      engine.skip();
      final data = live.updates.last;
      expect(data['title'], 'B');
      expect(data['phase'], 'rest');
      expect(data['step'], 2);
      expect(data['steps'], 2);
      expect(data['next'], 'Finish');
    });

    test('ends the Live Activity once when the workout finishes', () {
      engine = TimerEngine(segments, live: live)..start();
      engine.skip();
      engine.skip();
      expect(live.ended, 1);
    });
  });

  group('pause and resume', () {
    test('seconds hold while paused and resume adds no time', () async {
      engine = TimerEngine(segments)..start();
      engine.pause();
      final shown = engine.remainingSeconds;
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(engine.remainingSeconds, shown);
      engine.resume();
      expect(engine.remainingSeconds, shown);
    });
  });

  // These wait on the real clock (the engine reads DateTime.now), so they
  // use 1-second segments to stay quick.
  group('automatic segment changes', () {
    const short = [
      Segment(SegmentType.work, 'A', '', 1, block: 0),
      Segment(SegmentType.rest, 'B', '', 1, block: 0),
    ];

    test('moves to the next segment when time runs out', () async {
      engine = TimerEngine(short)..start();
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      expect(engine.index, 1);
      expect(engine.remainingSeconds, 1);
    });

    test('finishes after the last segment', () async {
      engine = TimerEngine(short)..start();
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(engine.finished, isTrue);
    });

    test('vibrates like a skip', () async {
      var longVibrations = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate' && call.arguments == null) {
          longVibrations++;
        }
        return null;
      });
      engine = TimerEngine(const [
        Segment(SegmentType.rest, 'A', '', 1, block: 0),
        Segment(SegmentType.work, 'B', '', 5, block: 1),
      ])
        ..start();
      // Change at 1 s, second vibration 0.7 s later; finish is far off.
      await Future<void>.delayed(const Duration(milliseconds: 2000));
      expect(longVibrations, 2);
    });
  });
}