import 'package:flutter_test/flutter_test.dart';
import 'package:splits/models/workout.dart';

Workout example() => Workout(
      id: 'w1',
      name: 'Example',
      warmupSeconds: 300,
      cooldownSeconds: 300,
      blocks: [
        IntervalBlock(reps: 2, workSeconds: 60, restSeconds: 30),
        IntervalBlock(reps: 3, workSeconds: 120, restSeconds: 60),
        IntervalBlock(reps: 2, workSeconds: 60, restSeconds: 30),
      ],
    );

void main() {
  group('Workout.toSegments', () {
    test('flattens the example into 15 segments', () {
      expect(example().toSegments().length, 15);
    });

    test('total duration is 1470 seconds', () {
      expect(example().totalSeconds, 1470);
    });

    test('starts with warm-up and ends with cool-down', () {
      final s = example().toSegments();
      expect(s.first.type, SegmentType.warmup);
      expect(s.last.type, SegmentType.cooldown);
    });

    test('no rest after the very last rep', () {
      final w = Workout(
        id: 'w2',
        name: 'No extras',
        blocks: [IntervalBlock(reps: 2, workSeconds: 60, restSeconds: 30)],
      );
      final types = w.toSegments().map((s) => s.type).toList();
      expect(types, [SegmentType.work, SegmentType.rest, SegmentType.work]);
    });

    test('skips warm-up and cool-down when zero', () {
      final w = Workout(
        id: 'w3',
        name: 'Bare',
        blocks: [IntervalBlock(reps: 1, workSeconds: 45)],
      );
      final s = w.toSegments();
      expect(s.length, 1);
      expect(s.single.seconds, 45);
    });

    test('empty workout has no segments', () {
      expect(Workout(id: 'w4', name: 'Empty').toSegments(), isEmpty);
    });

    test('tags intervals and rests with their block index', () {
      final blocks = example().toSegments().map((s) => s.block).toList();
      expect(blocks, [
        null, // warm-up
        0, 0, 0, 0, // 2 reps, rest after each (more blocks follow)
        1, 1, 1, 1, 1, 1, // 3 reps, rest after each
        2, 2, 2, // 2 reps, no rest after the very last one
        null, // cool-down
      ]);
    });
  });

  group('JSON', () {
    test('round-trips without losing data', () {
      final copy = Workout.fromJson(example().toJson());
      expect(copy.name, 'Example');
      expect(copy.blocks.length, 3);
      expect(copy.totalSeconds, 1470);
    });
  });
}