import 'chart_instant.dart';

String displayPlanetDegree(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value >= 30) {
    return 'Unavailable';
  }
  // Avoid rounding 29.9999 into an apparently out-of-sign 30.00 degrees.
  if (value >= 29.995) return '>29.99°';
  return '${value.toStringAsFixed(2)}°';
}

String displayIndiaTimestamp(Object? value) {
  DateTime? instant;
  if (value is DateTime) {
    instant = value;
  } else {
    instant = parseChartInstant(value);
  }
  if (instant == null) return 'Unavailable';
  final india = instant.toUtc().add(const Duration(hours: 5, minutes: 30));
  String two(int number) => number.toString().padLeft(2, '0');
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${two(india.day)} ${months[india.month - 1]} ${india.year}, ${two(india.hour)}:${two(india.minute)} IST (UTC+05:30)';
}
