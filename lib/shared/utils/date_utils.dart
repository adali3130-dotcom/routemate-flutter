import 'package:intl/intl.dart';

final _isoFmt = DateFormat('yyyy-MM-dd');
final _displayFmt = DateFormat('MMM d, yyyy');
final _dayFmt = DateFormat('EEE');

/// Returns the ISO Monday date string for the week containing [date].
/// Always uses UTC to avoid timezone-related off-by-one errors.
String weekStartFor(DateTime date) {
  final utc = date.toUtc();
  final monday = utc.subtract(Duration(days: utc.weekday - 1));
  return _isoFmt.format(monday);
}

/// Returns the ISO Monday date string for the current week (UTC).
String currentWeekStart() => weekStartFor(DateTime.now().toUtc());

/// Returns the ISO Monday date string for next week (UTC).
String nextWeekStart() {
  final utc = DateTime.now().toUtc();
  final monday = utc.subtract(Duration(days: utc.weekday - 1));
  return _isoFmt.format(monday.add(const Duration(days: 7)));
}

/// Parses an ISO date string to DateTime (UTC noon to avoid DST edge cases).
DateTime parseIsoDate(String isoDate) {
  final d = _isoFmt.parse(isoDate);
  return DateTime.utc(d.year, d.month, d.day, 12);
}

/// Formats an ISO date string for display, e.g. "Apr 21, 2025".
String formatDisplay(String isoDate) {
  return _displayFmt.format(parseIsoDate(isoDate));
}

/// Returns short day abbreviation for an ISO date string, e.g. "Mon".
String dayAbbrev(String isoDate) {
  return _dayFmt.format(parseIsoDate(isoDate));
}

/// Returns ISO date string for [date].
String toIsoDate(DateTime date) => _isoFmt.format(date.toUtc());
