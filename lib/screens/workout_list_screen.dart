import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../services/live_activity_service.dart';
import '../services/workout_store.dart';
import '../utils/format.dart';
import 'run_screen.dart';
import 'workout_editor_screen.dart';

class WorkoutListScreen extends StatelessWidget {
  const WorkoutListScreen(
      {super.key, required this.store, required this.live});
  final WorkoutStore store;
  final LiveActivityService live;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Splits')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, store.create()),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) => ListView(
          children: [
            for (final w in List.of(store.workouts))
              Dismissible(
                key: ValueKey(w.id),
                background: Container(color: Colors.red),
                onDismissed: (_) => store.remove(w),
                child: ListTile(
                  title: Text(w.name),
                  subtitle: Text(
                      '${w.blocks.map((b) => '${b.reps}×${fmtLong(b.workSeconds)}').join(' · ')}\nTotal ${fmtLong(w.totalSeconds)}'),
                  isThreeLine: true,
                  leading: IconButton(
                    icon: const Icon(Icons.play_circle_fill, size: 36),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => RunScreen(workout: w, live: live)),
                    ),
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => _edit(context, w),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _edit(BuildContext context, Workout workout) => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                WorkoutEditorScreen(store: store, workout: workout)),
      );
}
