class DailyEntry {
  final String date;
  final String startTime;
  final String endTime;
  final double mileage;
  final String totalTime;
  final String notes;

  const DailyEntry({
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.mileage,
    required this.totalTime,
    required this.notes,
  });

  factory DailyEntry.fromMap(Map<String, dynamic> map) {
    return DailyEntry(
      date: map['date'] as String? ?? '',
      startTime: map['start_time'] as String? ?? '',
      endTime: map['end_time'] as String? ?? '',
      mileage: (map['mileage'] as num?)?.toDouble() ?? 0.0,
      totalTime: map['totalTime'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'start_time': startTime,
      'end_time': endTime,
      'mileage': mileage,
      'totalTime': totalTime,
      'notes': notes,
    };
  }
}

class Timesheet {
  final String driverEmail;
  final String weekStart;
  final String companyId;
  final List<DailyEntry> days;

  const Timesheet({
    required this.driverEmail,
    required this.weekStart,
    required this.companyId,
    required this.days,
  });

  factory Timesheet.fromMap(Map<String, dynamic> map) {
    final rawDays = map['days'] as List<dynamic>? ?? [];
    return Timesheet(
      driverEmail: map['driver_email'] as String? ?? '',
      weekStart: map['week_start'] as String? ?? '',
      companyId: map['company_id'] as String? ?? '',
      days: rawDays
          .map((d) => DailyEntry.fromMap(d as Map<String, dynamic>))
          .toList(),
    );
  }

  static String docId(String driverEmail, String weekStart) =>
      '${driverEmail}__$weekStart';
}
