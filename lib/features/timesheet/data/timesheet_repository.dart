import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import '../domain/timesheet.dart';

class TimesheetRepository {
  final FirebaseFirestore _firestore;

  TimesheetRepository(this._firestore);

  Future<Timesheet?> fetchTimesheet(
    String driverEmail,
    String weekStart,
  ) async {
    final docId = Timesheet.docId(driverEmail, weekStart);
    try {
      final doc = await _firestore.collection('timesheets').doc(docId).get();
      if (!doc.exists || doc.data() == null) return null;
      return Timesheet.fromMap(doc.data()!);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  /// Upserts a daily entry — replaces any existing entry for the same date
  /// so re-saving a day never creates duplicate rows.
  Future<void> saveDailyEntry({
    required String driverEmail,
    required String weekStart,
    required String companyId,
    required DailyEntry entry,
  }) async {
    final docId = Timesheet.docId(driverEmail, weekStart);
    final docRef = _firestore.collection('timesheets').doc(docId);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);

      List<dynamic> days = [];
      if (snap.exists && snap.data() != null) {
        days = List<dynamic>.from(
          snap.data()!['days'] as List<dynamic>? ?? [],
        );
      }

      // Remove any existing entry for this date (upsert)
      days.removeWhere(
        (d) => (d as Map<String, dynamic>)['date'] == entry.date,
      );
      days.add(entry.toMap());

      tx.set(
        docRef,
        {
          'driver_email': driverEmail,
          'week_start': weekStart,
          'company_id': companyId,
          'days': days,
        },
        SetOptions(merge: true),
      );
    });
  }

  /// Calls the `sendTimesheetEmail` Firebase callable function.
  /// Passes the full week's entries so the Cloud Function can format a
  /// complete summary email.
  Future<void> submitTimesheetEmail({
    required String idToken,
    required String driverEmail,
    required String weekStart,
    required List<DailyEntry> days,
  }) async {
    const region = 'us-central1';
    const projectId = 'routemate-f2a00';
    final uri = Uri.parse(
      'https://$region-$projectId.cloudfunctions.net/sendTimesheetEmail',
    );

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode({
        'data': {
          'driver_email': driverEmail,
          'week_start': weekStart,
          'entries': days.map((d) => d.toMap()).toList(),
        },
      }),
    );

    if (response.statusCode != 200) {
      // Parse Firebase callable error if present
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final error = body['error'] as Map<String, dynamic>?;
        final msg = error?['message'] as String?;
        throw Exception(msg ?? 'Server error ${response.statusCode}');
      } catch (_) {
        throw Exception('Submit failed (${response.statusCode})');
      }
    }
  }
}
