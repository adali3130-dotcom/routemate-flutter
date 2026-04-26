import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../domain/visit.dart';
import '../domain/weekly_plan.dart';

class WeeklyPlanRepository {
  final FirebaseFirestore _firestore;

  WeeklyPlanRepository(this._firestore);

  Future<WeeklyPlan?> fetchPlan(String driverUid) async {
    final now = DateTime.now().toUtc();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final fmt = DateFormat('yyyy-MM-dd');
    final thisWeekStart = fmt.format(monday);
    final nextWeekStart = fmt.format(monday.add(const Duration(days: 7)));

    // Try next week first, fall back to current week
    final nextWeekQuery = await _firestore
        .collection('weekly_plans')
        .where('driver_uid', isEqualTo: driverUid)
        .where('week_start', isEqualTo: nextWeekStart)
        .limit(1)
        .get();

    final weekStart =
        nextWeekQuery.docs.isNotEmpty ? nextWeekStart : thisWeekStart;

    final query = await _firestore
        .collection('weekly_plans')
        .where('driver_uid', isEqualTo: driverUid)
        .where('week_start', isEqualTo: weekStart)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    final plan = WeeklyPlan.fromMap(doc.id, doc.data());
    return _enrichVisitAddresses(plan);
  }

  Future<WeeklyPlan> _enrichVisitAddresses(WeeklyPlan plan) async {
    final enriched = await Future.wait(
      plan.visits.map((visit) async {
        if (visit.address.trim().isNotEmpty) return visit;
        try {
          final accountDoc = await _firestore
              .collection('accounts')
              .doc(visit.accountId)
              .get();
          final address =
              accountDoc.data()?['address'] as String? ?? '';
          return visit.copyWith(address: address);
        } catch (_) {
          return visit;
        }
      }),
    );
    return plan.copyWith(visits: enriched);
  }

  Future<void> markVisitComplete(
    String planId,
    List<Visit> updatedVisits,
  ) async {
    await _firestore.collection('weekly_plans').doc(planId).update({
      'visits': updatedVisits.map((v) => v.toMap()).toList(),
    });
  }
}
