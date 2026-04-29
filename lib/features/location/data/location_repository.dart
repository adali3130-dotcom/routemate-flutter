import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationRepository {
  final FirebaseFirestore _firestore;

  LocationRepository(this._firestore);

  Stream<QuerySnapshot> pendingRequestsStream(String driverEmail) {
    return _firestore
        .collection('location_requests')
        .where('driver_email', isEqualTo: driverEmail)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> respondToRequest(String requestId, String driverEmail) async {
    final status = await Permission.location.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      await _firestore
          .collection('location_requests')
          .doc(requestId)
          .update({'status': 'denied'});
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final batch = _firestore.batch();

      batch.set(
        _firestore.collection('driver_locations').doc(driverEmail),
        {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'timestamp': FieldValue.serverTimestamp(),
          'driver_email': driverEmail,
        },
      );

      batch.update(
        _firestore.collection('location_requests').doc(requestId),
        {'status': 'done'},
      );

      await batch.commit();
    } catch (_) {
      await _firestore
          .collection('location_requests')
          .doc(requestId)
          .update({'status': 'denied'});
    }
  }
}
