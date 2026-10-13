import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/workout_store.dart';
import '../widgets/duration_stepper.dart';

class WorkoutEditorScreen extends StatefulWidget {
  const WorkoutEditorScreen(
      {super.key, required this.store, required this.workout});
  final WorkoutStore store;
  final Workout workout;

  @override
  State<WorkoutEditorScreen> createState() => _WorkoutEditorScreenState();
}

class _WorkoutEditorScreenState extends State<WorkoutEditorScreen> {
  // Working copy so "back" discards edits.
  late final Workout w = Workout.fromJson(widget.workout.toJson());
  late final _name = TextEditingController(text: w.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit workout'),
        actions: [
          TextButton(
            onPressed: () async {
              final n = _name.text.trim();
              w.name = n.isEmpty ? 'Workout' : n;
              await widget.store.upsert(w);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 16),
          DurationStepper(
              label: 'Warm-up',
              seconds: w.warmupSeconds,
              step: 30,
              onChanged: (v) => setState(() => w.warmupSeconds = v)),
          const Divider(height: 32),
          for (var i = 0; i < w.blocks.length; i++) _blockCard(i),
          OutlinedButton.icon(
            onPressed: () => setState(() => w.blocks.add(IntervalBlock())),
            icon: const Icon(Icons.add),
            label: const Text('Add block'),
          ),
          const Divider(height: 32),
          DurationStepper(
              label: 'Cool-down',
              seconds: w.cooldownSeconds,
              step: 30,
              onChanged: (v) => setState(() => w.cooldownSeconds = v)),
        ],
      ),
    );
  }

  Widget _blockCard(int i) {
    final b = w.blocks[i];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(children: [
              Text('Block ${i + 1}',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() => w.blocks.removeAt(i)),
              ),
            ]),
            Row(children: [
              const Expanded(child: Text('Repetitions')),
              IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed:
                      b.reps > 1 ? () => setState(() => b.reps--) : null),
              Text('${b.reps}'),
              IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => b.reps++)),
            ]),
            DurationStepper(
                label: 'Interval',
                seconds: b.workSeconds,
                min: 5,
                onChanged: (v) => setState(() => b.workSeconds = v)),
            DurationStepper(
                label: 'Rest (optional)',
                seconds: b.restSeconds,
                onChanged: (v) => setState(() => b.restSeconds = v)),
          ],
        ),
      ),
    );
  }
}
