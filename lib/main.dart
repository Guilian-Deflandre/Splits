import 'package:flutter/material.dart';
import 'screens/workout_list_screen.dart';
import 'services/live_activity_service.dart';
import 'services/workout_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = WorkoutStore();
  final live = LiveActivityService();
  await Future.wait([store.load(), live.init()]);
  runApp(SplitsApp(store: store, live: live));
}

class SplitsApp extends StatelessWidget {
  const SplitsApp({super.key, required this.store, required this.live});
  final WorkoutStore store;
  final LiveActivityService live;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Splits',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: WorkoutListScreen(store: store, live: live),
    );
  }
}
