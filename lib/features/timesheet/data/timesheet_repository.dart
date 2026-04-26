import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/timesheet.dart';

class TimesheetRepository {
  final FirebaseFirestore _firestore;

  TimesheetRepository(this._firestore);

  Future<Timesheet?> fetchTimesheet(
    String driverEmail,
    String weekStart,
  ) async {
    final docId = Timesheet.docId(driverEmail, weekStart);
    final doc = await _firestore.collection('timesheets').doc(docId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Timesheet.fromMap(doc.data()!);
  }

  Future<void> saveDailyEntry({
    required String driverEmail,
    required String weekStart,
    required String companyId,
    required DailyEntry entry,
  }) async {
    final docId = Timesheet.docId(driverEmail, weekStart);
    await _firestore.collection('timesheets').doc(docId).set(
      {
        'driver_email': driverEmail,
        'week_start': weekStart,
        'company_id': companyId,
        'days': FieldValue.arrayUnion([entry.toMap()]),
      },
      SetOptions(merge: true),
    );
  }
}
