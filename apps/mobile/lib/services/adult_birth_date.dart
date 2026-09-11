/// Date-only 13+ profile cutoff in the India calendar, independent of the
/// phone timezone. Clamp leap day instead of normalizing it to March 1.
DateTime latestEligibleBirthDate(DateTime now) {
  final today = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  final year = today.year - 13;
  final lastDay = DateTime(year, today.month + 1, 0).day;
  return DateTime(year, today.month, today.day > lastDay ? lastDay : today.day);
}
