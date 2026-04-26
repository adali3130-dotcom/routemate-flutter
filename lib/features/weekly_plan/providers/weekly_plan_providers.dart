import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/weekly_plan_repository.dart';
import '../domain/weekly_plan.dart';

final weeklyPlanRepositoryProvider = Provider<WeeklyPlanRepository>((ref) {
  return WeeklyPlanRepository(FirebaseFirestore.instance);
});

class WeeklyPlanNotifier extends AsyncNotifier<WeeklyPlan?> {
  @override
  Future<WeeklyPlan?> build() async {
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) return null;
    return ref.read(weeklyPlanRepositoryProvider).fetchPlan(user.uid);
  }

  Future<void> markVisitComplete(String accountId, String date) async {
    final plan = state.valueOrNull;
    if (plan == null) return;

    // Optimistic update for instant UI feedback
    final optimisticVisits = plan.visits.map((v) {
      if (v.accountId == accountId && v.date == date) {
        return v.copyWith(completed: true);
      }
      return v;
    }).toList();
    state = AsyncValue.data(plan.copyWith(visits: optimisticVisits));

    try {
      await ref.read(weeklyPlanRepositoryProvider).markVisitComplete(
        plan.planId,
        accountId,
        date,
      );
    } catch (e, st) {
      // Revert to pre-update state on failure
      state = AsyncValue.data(plan);
      Error.throwWithStackTrace(e, st);
    }
  }
}

final weeklyPlanProvider =
    AsyncNotifierProvider<WeeklyPlanNotifier, WeeklyPlan?>(WeeklyPlanNotifier.new);
