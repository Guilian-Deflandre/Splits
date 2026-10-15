import 'package:flutter_test/flutter_test.dart';
import 'package:splits/main.dart';
import 'package:splits/models/workout.dart';
import 'package:splits/services/live_activity_service.dart';
import 'package:splits/services/workout_store.dart';

void main() {
  testWidgets('list screen shows saved workouts', (tester) async {
    final store = WorkoutStore()
      ..workouts.add(Workout(
        id: 'w1',
        name: 'Test workout',
        blocks: [IntervalBlock(reps: 2, workSeconds: 60)],
      ));

    await tester.pumpWidget(
      SplitsApp(store: store, live: LiveActivityService()),
    );

    expect(find.text('Splits'), findsOneWidget);
    expect(find.text('Test workout'), findsOneWidget);
    expect(find.textContaining('2×1 min'), findsOneWidget);
    expect(find.textContaining('Total 2 min'), findsOneWidget);
  });
}