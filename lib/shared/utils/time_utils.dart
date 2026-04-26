import 'package:flutter/material.dart';

/// Formats a [TimeOfDay] as "HH:MM" (24-hour).
String formatTime(TimeOfDay time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Parses an "HH:MM" string to [TimeOfDay]. Returns null if invalid.
TimeOfDay? parseTime(String time) {
  final parts = time.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// Computes total duration string between start and end times, e.g. "2h 15m".
/// Returns empty string if end is before start.
String computeTotalTime(TimeOfDay start, TimeOfDay end) {
  final startMinutes = start.hour * 60 + start.minute;
  final endMinutes = end.hour * 60 + end.minute;
  final diff = endMinutes - startMinutes;
  if (diff <= 0) return '';
  final hours = diff ~/ 60;
  final minutes = diff % 60;
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}
