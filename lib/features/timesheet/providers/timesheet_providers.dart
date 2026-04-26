import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/timesheet_repository.dart';

final timesheetRepositoryProvider = Provider<TimesheetRepository>((ref) {
  return TimesheetRepository(FirebaseFirestore.instance);
});
