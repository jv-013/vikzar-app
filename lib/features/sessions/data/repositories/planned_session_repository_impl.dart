import 'package:cloud_firestore/cloud_firestore.dart';
// `cloud_functions` also exports a `Result` type, colliding with this
// codebase's own `core/result/result.dart` — hidden here since only
// `FirebaseFunctions`/`FirebaseFunctionsException` are needed.
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/cloud_function_failure_mapper.dart';
import '../../../../core/errors/firestore_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../../../services/firebase/firestore_service.dart';
import '../../../../services/firebase/functions_service.dart';
import '../../domain/models/planned_session.dart';
import '../../domain/repositories/planned_session_repository.dart';

class PlannedSessionRepositoryImpl implements PlannedSessionRepository {
  PlannedSessionRepositoryImpl(this._firestore, this._functions);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _plannedSessions =>
      _firestore.collection('plannedSessions');

  @override
  Stream<Result<List<PlannedSession>>> watchUpcoming(String teamId) async* {
    try {
      final query = _plannedSessions
          .where('teamId', isEqualTo: teamId)
          .orderBy('scheduledAt');
      await for (final snapshot in query.snapshots()) {
        // Cancelled sessions stay in Firestore for audit purposes but
        // never appear in "Upcoming" — filtered client-side rather than
        // via an extra composite index+where clause solely to exclude
        // one status value.
        final sessions = [
          for (final doc in snapshot.docs)
            PlannedSession.fromMap(_normalize(doc.data()), plannedSessionId: doc.id),
        ].where((session) => session.status != PlannedSessionStatus.cancelled).toList();
        yield Result.success(sessions);
      }
    } catch (e) {
      yield Result.failure(mapFirestoreError(e));
    }
  }

  /// Converts Firestore's `Timestamp` into a plain `DateTime` before
  /// handing the map to [PlannedSession.fromMap] — the same pattern
  /// `AlertRepositoryImpl`/`NotificationRepositoryImpl` use.
  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final scheduledAt = data['scheduledAt'];
    return {
      ...data,
      'scheduledAt': scheduledAt is Timestamp ? scheduledAt.toDate() : DateTime.now(),
    };
  }

  @override
  Future<Result<void>> createPlannedSession({
    required String teamId,
    required String title,
    required PlannedSessionType type,
    required DateTime scheduledAt,
    String? notes,
  }) async {
    try {
      final callable = _functions.httpsCallable('createPlannedSession');
      await callable.call<Map<String, dynamic>>({
        'teamId': teamId,
        'title': title,
        'type': type.firestoreKey,
        'scheduledAt': scheduledAt.toUtc().toIso8601String(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
      return const Result.success(null);
    } catch (e) {
      // A single catch, not `on FirebaseFunctionsException` / `catch`
      // pair — mapCloudFunctionError itself distinguishes typed vs.
      // untyped errors, matching mapFirestoreError's own documented
      // reasoning for the same pattern.
      return Result.failure(mapCloudFunctionError(e));
    }
  }
}

final plannedSessionRepositoryProvider = Provider<PlannedSessionRepository>((ref) {
  return PlannedSessionRepositoryImpl(ref.watch(firestoreProvider), ref.watch(functionsProvider));
});
