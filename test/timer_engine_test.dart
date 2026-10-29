import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splits/models/workout.dart';
import 'package:splits/services/timer_engine.dart';

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
}