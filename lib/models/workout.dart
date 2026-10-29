enum SegmentType { warmup, work, rest, cooldown }

/// One step of the flattened timeline the engine actually runs.

class Segment {
  const Segment(this.type, this.title, this.detail, this.seconds, {this.block});
  final SegmentType type;
  final String title; // "Interval", "Rest"...
  final String detail; // "Block 2 · 1/3"
  final int seconds;
  final int? block; // index into Workout.blocks; null for warm-up/cool-down
}

/// "reps x work, with optional rest between reps" — e.g. 3 x 2:00 / 0:30 rest.
class IntervalBlock {
  IntervalBlock({this.reps = 2, this.workSeconds = 60, this.restSeconds = 0});
  int reps;
  int workSeconds;
  int restSeconds;

  Map<String, dynamic> toJson() =>
      {'reps': reps, 'work': workSeconds, 'rest': restSeconds};

  factory IntervalBlock.fromJson(Map<String, dynamic> j) => IntervalBlock(
        reps: j['reps'] as int,
        workSeconds: j['work'] as int,
        restSeconds: j['rest'] as int,
      );
}

class Workout {
  Workout({
    required this.id,
    required this.name,
    this.warmupSeconds = 0,
    this.cooldownSeconds = 0,
    List<IntervalBlock>? blocks,
  }) : blocks = blocks ?? [];

  final String id;
  String name;
  int warmupSeconds;
  int cooldownSeconds;
  List<IntervalBlock> blocks;

  /// Flattens blocks into an ordered timeline. Rest follows every rep except
  /// the very last one of the workout.
  List<Segment> toSegments() {
    final out = <Segment>[];
    if (warmupSeconds > 0) {
      out.add(Segment(SegmentType.warmup, 'Warm-up', '', warmupSeconds));
    }
    for (var b = 0; b < blocks.length; b++) {
      final block = blocks[b];
      for (var r = 1; r <= block.reps; r++) {
        out.add(Segment(SegmentType.work, 'Interval',
            'Block ${b + 1} · $r/${block.reps}', block.workSeconds,
            block: b));
        final isLast = b == blocks.length - 1 && r == block.reps;
        if (block.restSeconds > 0 && !isLast) {
          out.add(Segment(SegmentType.rest, 'Rest',
              'Block ${b + 1} · $r/${block.reps}', block.restSeconds,
              block: b));
        }
      }
    }
    if (cooldownSeconds > 0) {
      out.add(Segment(SegmentType.cooldown, 'Cool-down', '', cooldownSeconds));
    }
    return out;
  }

  int get totalSeconds => toSegments().fold(0, (sum, s) => sum + s.seconds);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'warmup': warmupSeconds,
        'cooldown': cooldownSeconds,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  factory Workout.fromJson(Map<String, dynamic> j) => Workout(
        id: j['id'] as String,
        name: j['name'] as String,
        warmupSeconds: j['warmup'] as int,
        cooldownSeconds: j['cooldown'] as int,
        blocks: (j['blocks'] as List)
            .map((e) => IntervalBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
