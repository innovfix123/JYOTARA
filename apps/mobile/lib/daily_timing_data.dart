/// Provider timing boundaries, kept separate from presentation and playback.
class DailyTimingWindow {
  const DailyTimingWindow(this.start, this.end);

  static const indiaOffset = Duration(hours: 5, minutes: 30);
  final DateTime start;
  final DateTime end;

  static DailyTimingWindow? fromProvider(Map? row) {
    final start = DateTime.tryParse('${row?['start']}');
    final end = DateTime.tryParse('${row?['end']}');
    if (start == null || end == null || !start.isBefore(end)) return null;
    return DailyTimingWindow(start, end);
  }

  static DateTime midnight(String date) =>
      DateTime.parse('${date}T00:00:00+05:30');

  /// A 24-hour lane clips at the selected day's boundaries, including windows
  /// crossing midnight. Exact provider times remain available in the labels.
  ({double start, double end})? lane(String date) {
    final midnight = DailyTimingWindow.midnight(date);
    final startFraction =
        (start.difference(midnight).inMilliseconds /
                Duration.millisecondsPerDay)
            .clamp(0.0, 1.0);
    final endFraction =
        (end.difference(midnight).inMilliseconds / Duration.millisecondsPerDay)
            .clamp(0.0, 1.0);
    if (endFraction <= startFraction) return null;
    return (start: startFraction, end: endFraction);
  }

  bool overlaps(DailyTimingWindow other) =>
      start.isBefore(other.end) && other.start.isBefore(end);

  static double? nowFraction(String date, DateTime now) {
    final midnight = DailyTimingWindow.midnight(date);
    final elapsed = now.difference(midnight).inMilliseconds;
    if (elapsed < 0 || elapsed >= Duration.millisecondsPerDay) return null;
    return elapsed / Duration.millisecondsPerDay;
  }
}
