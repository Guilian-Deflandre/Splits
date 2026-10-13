String fmt(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

String fmtLong(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final r = totalSeconds % 60;
  if (m == 0) return '${r}s';
  if (r == 0) return '$m min';
  return '$m min ${r}s';
}
