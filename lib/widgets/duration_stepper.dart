import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../utils/format.dart';

class DurationStepper extends StatelessWidget {
  const DurationStepper({
    super.key,
    required this.label,
    required this.seconds,
    required this.onChanged,
    this.step = 5,
    this.min = 0,
  });

  final String label;
  final int seconds;
  final int step;
  final int min;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed:
              seconds - step >= min ? () => onChanged(seconds - step) : null,
        ),
        SizedBox(
          width: 56,
          child: Text(fmt(seconds),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFeatures: [FontFeature.tabularFigures()])),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(seconds + step),
        ),
      ],
    );
  }
}
