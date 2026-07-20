import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/firestore_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../../../services/firebase/firestore_service.dart';
import '../../domain/models/coach_request.dart';
import '../../domain/repositories/coach_request_repository.dart';

class CoachRequestRepositoryImpl implements CoachRequestRepository {
  CoachRequestRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<Result<void>> submit(CoachRequest request) async {
    try {
      final docRef = _firestore.collection('coachRequests').doc();
      await docRef.set({
        'requestId': docRef.id,
        ...request.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }
}

final coachRequestRepositoryProvider = Provider<CoachRequestRepository>((ref) {
  return CoachRequestRepositoryImpl(ref.watch(firestoreProvider));
});
