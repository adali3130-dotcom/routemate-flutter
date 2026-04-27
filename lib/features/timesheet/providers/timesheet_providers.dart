import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/date_utils.dart';
import '../../auth/providers/auth_providers.dart';
import '../data/timesheet_repository.dart';
import '../domain/timesheet.dart';

final timesheetRepositoryProvider = Provider<TimesheetRepository>((ref) {
  return TimesheetRepository(FirebaseFirestore.instance);
});

/// Loads the timesheet document for the current week.
/// Invalidate this provider after saving an entry to reload.
final timesheetProvider = FutureProvider<Timesheet?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null || user.email == null) return null;
  return ref.read(timesheetRepositoryProvider).fetchTimesheet(
    user.email!,
    currentWeekStart(),
  );
});
