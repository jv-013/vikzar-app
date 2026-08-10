import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/firestore_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../../../services/firebase/firestore_service.dart';
import '../../domain/models/live_player_metrics.dart';
import '../../domain/repositories/live_monitoring_repository.dart';

class LiveMonitoringRepositoryImpl implements LiveMonitoringRepository {
  LiveMonitoringRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _liveMonitoring(String teamId) =>
      _firestore.collection('teams').doc(teamId).collection('liveMonitoring');

  @override
  Stream<Result<List<LivePlayerMetrics>>> watchTeamLiveMonitoring(String teamId) async* {
    try {
      await for (final snapshot in _liveMonitoring(teamId).snapshots()) {
        yield Result.success([
          for (final doc in snapshot.docs)
            LivePlayerMetrics.fromMap(_normalize(doc.data()), playerId: doc.id),
        ]);
      }
    } catch (e) {
      yield Result.failure(mapFirestoreError(e));
    }
  }

  /// Converts Firestore's `Timestamp` fields into plain [DateTime] before
  /// handing the map to [LivePlayerMetrics.fromMap] — the same normalization
  /// [AlertRepositoryImpl] performs, keeping the domain model itself free of
  /// any Firebase dependency.
  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final lastTickAt = data['lastTickAt'];
    final updatedAt = data['updatedAt'];
    return {
      ...data,
      'lastTickAt': lastTickAt is Timestamp ? lastTickAt.toDate() : DateTime.now(),
      if (updatedAt is Timestamp) 'updatedAt': updatedAt.toDate(),
    };
  }
}

final liveMonitoringRepositoryProvider = Provider<LiveMonitoringRepository>((ref) {
  return LiveMonitoringRepositoryImpl(ref.watch(firestoreProvider));
});
