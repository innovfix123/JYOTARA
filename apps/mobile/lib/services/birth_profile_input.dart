import 'chart_instant.dart';

/// Editable inputs reconstructed from the stored calculation key, not from
/// inferred chart facts. Legacy records need no new provider request.
class BirthProfileInput {
  const BirthProfileInput(
    this.dateTime,
    this.latitude,
    this.longitude,
    this.exactTime,
  );
  final String dateTime;
  final double latitude;
  final double longitude;
  final bool exactTime;
  DateTime get indiaDateTime =>
      parseChartInstant(dateTime)!
          .toUtc()
          .add(const Duration(hours: 5, minutes: 30));

  static BirthProfileInput? fromKey(String? key) {
    final parts = key?.split('|');
    if (parts == null ||
        parts.length != 4 ||
        parseChartInstant(parts[0]) == null) {
      return null;
    }
    final lat = double.tryParse(parts[1]);
    final lon = double.tryParse(parts[2]);
    if (lat == null ||
        lon == null ||
        !lat.isFinite ||
        !lon.isFinite ||
        lat.abs() > 90 ||
        lon.abs() > 180 ||
        !['true', 'false'].contains(parts[3])) {
      return null;
    }
    return BirthProfileInput(parts[0], lat, lon, parts[3] == 'true');
  }
}
