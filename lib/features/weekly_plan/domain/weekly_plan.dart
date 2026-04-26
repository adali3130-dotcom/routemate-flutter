import 'visit.dart';

class WeeklyPlan {
  final String planId;
  final String driverUid;
  final String driverId;
  final String weekStart;
  final String companyId;
  final List<Visit> visits;

  const WeeklyPlan({
    required this.planId,
    required this.driverUid,
    required this.driverId,
    required this.weekStart,
    required this.companyId,
    required this.visits,
  });

  factory WeeklyPlan.fromMap(String id, Map<String, dynamic> map) {
    final rawVisits = map['visits'] as List<dynamic>? ?? [];
    return WeeklyPlan(
      planId: id,
      driverUid: map['driver_uid'] as String? ?? '',
      driverId: map['driver_id'] as String? ?? '',
      weekStart: map['week_start'] as String? ?? '',
      companyId: map['company_id'] as String? ?? '',
      visits: rawVisits
          .map((v) => Visit.fromMap(v as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plan_id': planId,
      'driver_uid': driverUid,
      'driver_id': driverId,
      'week_start': weekStart,
      'company_id': companyId,
      'visits': visits.map((v) => v.toMap()).toList(),
    };
  }

  WeeklyPlan copyWith({List<Visit>? visits}) {
    return WeeklyPlan(
      planId: planId,
      driverUid: driverUid,
      driverId: driverId,
      weekStart: weekStart,
      companyId: companyId,
      visits: visits ?? this.visits,
    );
  }
}
