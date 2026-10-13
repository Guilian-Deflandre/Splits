import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/live_activity_service.dart';
import '../services/timer_engine.dart';
import '../utils/format.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key, required this.workout, required this.live});
  final Workout workout;
  final LiveActivityService live;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  late final TimerEngine engine;

  @override
  void initState() {
    super.initState();
    engine = TimerEngine(widget.workout.toSegments(), live: widget.live)
      ..start();
  }

  @override
  void dispose() {
    engine.stop();
    engine.dispose();
    super.dispose();
  }

  Color _color(SegmentType t) => switch (t) {
        SegmentType.work => Colors.green,
        SegmentType.rest => Colors.orange,
        SegmentType.warmup => Colors.blue,
        SegmentType.cooldown => Colors.teal,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        if (engine.finished) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.workout.name)),
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle, size: 96, color: Colors.green),
                const SizedBox(height: 16),
                Text('Done!',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 24),
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
              ]),
            ),
          );
        }
        final seg = engine.current;
        final color = _color(seg.type);
        final secs = (engine.remaining.inMilliseconds / 1000).ceil();
        return Scaffold(
          backgroundColor: color.withOpacity(0.18),
          appBar: AppBar(
            title: Text(widget.workout.name),
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  Text(seg.title.toUpperCase(),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: color, fontWeight: FontWeight.bold)),
                  Text(seg.detail),
                  const SizedBox(height: 16),
                  Text(fmt(secs),
                      style: const TextStyle(
                          fontSize: 96,
                          fontWeight: FontWeight.w200,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  LinearProgressIndicator(
                      value: engine.segmentProgress, color: color),
                  const SizedBox(height: 16),
                  Text(engine.next == null
                      ? 'Next: finish'
                      : 'Next: ${engine.next!.title} · ${fmtLong(engine.next!.seconds)}'),
                  Text('Step ${engine.index + 1} of ${engine.segments.length}'),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton.filledTonal(
                        iconSize: 36,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.stop),
                      ),
                      IconButton.filled(
                        iconSize: 48,
                        onPressed:
                            engine.paused ? engine.resume : engine.pause,
                        icon: Icon(
                            engine.paused ? Icons.play_arrow : Icons.pause),
                      ),
                      IconButton.filledTonal(
                        iconSize: 36,
                        onPressed: engine.skip,
                        icon: const Icon(Icons.skip_next),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
