/// Strict timezone-explicit provider timestamp. Dart's parser alone normalizes
/// invalid calendar dates, so validate the original calendar components first.
DateTime? parseChartInstant(Object? value) {
  if (value is! String) return null;
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(value);
  if (match == null) return null;
  int part(int index) => int.parse(match.group(index)!);
  final year = part(1), month = part(2), day = part(3);
  if (year < 1 ||
      month < 1 ||
      month > 12 ||
      day < 1 ||
      day > DateTime.utc(year, month + 1, 0).day ||
      part(4) > 23 ||
      part(5) > 59 ||
      part(6) > 59) {
    return null;
  }
  final zone = match.group(7)!;
  if (zone != 'Z' &&
      (int.parse(zone.substring(1, 3)) > 23 ||
          int.parse(zone.substring(4, 6)) > 59)) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
}
