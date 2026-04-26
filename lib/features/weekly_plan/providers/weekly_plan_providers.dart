import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../data/weekly_plan_repository.dart';
import '../domain/weekly_plan.dart';

final weeklyPlanRepositoryProvider = Provider<WeeklyPlanRepository>((ref) {
  return WeeklyPlanRepository(FirebaseFirestore.instance);
});

final weeklyPlanProvider = FutureProvider<WeeklyPlan?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;
  return ref.read(weeklyPlanRepositoryProvider).fetchPlan(user.uid);
});
