import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/workout.dart';

class WorkoutStore extends ChangeNotifier {
  static const _key = 'workouts_v1';
  final List<Workout> workouts = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      workouts
        ..clear()
        ..addAll(list.map((e) => Workout.fromJson(e as Map<String, dynamic>)));
    }
    if (workouts.isEmpty) {
      // Example 2x1 min, 3x2 min, 2x1 min.
      workouts.add(Workout(
        id: const Uuid().v4(),
        name: 'Example splits',
        warmupSeconds: 300,
        cooldownSeconds: 300,
        blocks: [
          IntervalBlock(reps: 2, workSeconds: 60, restSeconds: 30),
          IntervalBlock(reps: 3, workSeconds: 120, restSeconds: 60),
          IntervalBlock(reps: 2, workSeconds: 60, restSeconds: 30),
        ],
      ));
    }
    notifyListeners();
  }

  Workout create() => Workout(
      id: const Uuid().v4(), name: 'New workout', blocks: [IntervalBlock()]);

  Future<void> upsert(Workout w) async {
    final i = workouts.indexWhere((x) => x.id == w.id);
    if (i >= 0) {
      workouts[i] = w;
    } else {
      workouts.add(w);
    }
    await _save();
  }

  Future<void> remove(Workout w) async {
    workouts.removeWhere((x) => x.id == w.id);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(workouts.map((w) => w.toJson()).toList()));
    notifyListeners();
  }
}
