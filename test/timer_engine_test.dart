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
}