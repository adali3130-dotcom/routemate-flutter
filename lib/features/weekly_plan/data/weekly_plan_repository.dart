import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/utils/date_utils.dart';
import '../domain/visit.dart';
import '../domain/weekly_plan.dart';

class WeeklyPlanRepository {
  final FirebaseFirestore _firestore;

  WeeklyPlanRepository(this._firestore);

  Future<WeeklyPlan?> fetchPlan(String driverUid) async {
    final now = DateTime.now().toUtc();
    final thisWeek = weekStartFor(now);
    final nextWeek = nextWeekStart();

    // Try next week first, fall back to current week
    final nextWeekQuery = await _firestore
        .collection('weekly_plans')
        .where('driver_uid', isEqualTo: driverUid)
        .where('week_start', isEqualTo: nextWeek)
        .limit(1)
        .get();

    final weekStart = nextWeekQuery.docs.isNotEmpty ? nextWeek : thisWeek;

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
          final address = accountDoc.data()?['address'] as String? ?? '';
          return visit.copyWith(address: address);
        } catch (_) {
          return visit;
        }
      }),
    );
    return plan.copyWith(visits: enriched);
  }

  /// Atomically reads the Firestore document, flips the matching visit's
  /// completed flag to true, and writes the full visits array back.
  Future<void> markVisitComplete(
    String planId,
    String accountId,
    String date,
  ) async {
    final docRef = _firestore.collection('weekly_plans').doc(planId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (!snap.exists || snap.data() == null) return;

      final rawVisits = snap.data()!['visits'] as List<dynamic>? ?? [];
      final visits = rawVisits
          .map((v) => Visit.fromMap(v as Map<String, dynamic>))
          .toList();

      final updated = visits.map((v) {
        if (v.accountId == accountId && v.date == date) {
          return v.copyWith(completed: true);
        }
        return v;
      }).toList();

      tx.update(docRef, {
        'visits': updated.map((v) => v.toMap()).toList(),
      });
    });
  }
}
