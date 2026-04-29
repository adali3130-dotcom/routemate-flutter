import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location_repository.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository(FirebaseFirestore.instance);
});

class LocationService {
  final LocationRepository _repository;
  StreamSubscription<QuerySnapshot>? _subscription;

  LocationService(this._repository);

  void start(String driverEmail) {
    stop();
    _subscription = _repository
        .pendingRequestsStream(driverEmail)
        .listen(
          (snapshot) {
            for (final doc in snapshot.docs) {
              _repository
                  .respondToRequest(doc.id, driverEmail)
                  .catchError((_) {});
            }
          },
          onError: (_) {},
        );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
  }
}

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService(ref.watch(locationRepositoryProvider));
  ref.onDispose(service.stop);
  return service;
});
