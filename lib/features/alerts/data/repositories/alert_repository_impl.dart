import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/firestore_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../../../services/firebase/firestore_service.dart';
import '../../domain/models/alert.dart';
import '../../domain/repositories/alert_repository.dart';

class AlertRepositoryImpl implements AlertRepository {
  AlertRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _alerts => _firestore.collection('alerts');

  @override
  Stream<Result<List<Alert>>> watchAlerts(List<String> teamIds) async* {
    if (teamIds.isEmpty) {
      yield const Result.success([]);
      return;
    }
    try {
      final query = _alerts
          .where('teamId', whereIn: teamIds)
          .orderBy('triggeredAt', descending: true);
      await for (final snapshot in query.snapshots()) {
        yield Result.success([
          for (final doc in snapshot.docs) Alert.fromMap(_normalize(doc.data()), alertId: doc.id),
        ]);
      }
    } catch (e) {
      yield Result.failure(mapFirestoreError(e));
    }
  }

  /// Converts Firestore's `Timestamp` (a `cloud_firestore` SDK type) into
  /// a plain `DateTime` before handing the map to [Alert.fromMap] — keeping
  /// the domain model itself free of any Firebase dependency, per
  /// FLUTTER_ARCHITECTURE.md §1's dependency rule (the same pattern
  /// `NotificationRepositoryImpl` already uses).
  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final triggeredAt = data['triggeredAt'];
    final acknowledgedAt = data['acknowledgedAt'];
    return {
      ...data,
      'triggeredAt': triggeredAt is Timestamp ? triggeredAt.toDate() : DateTime.now(),
      if (acknowledgedAt is Timestamp) 'acknowledgedAt': acknowledgedAt.toDate(),
    };
  }

  @override
  Future<Result<void>> acknowledgeAlert({
    required String alertId,
    required String coachUid,
  }) async {
    try {
      await _alerts.doc(alertId).update({
        'acknowledged': true,
        'acknowledgedBy': coachUid,
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }
}

final alertRepositoryProvider = Provider<AlertRepository>((ref) {
  return AlertRepositoryImpl(ref.watch(firestoreProvider));
});
