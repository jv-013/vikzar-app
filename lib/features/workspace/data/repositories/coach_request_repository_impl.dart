import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
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
    } on FirebaseException catch (e) {
      return Result.failure(_mapException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  Failure _mapException(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return PermissionFailure(message: e.code, cause: e);
    }
    if (e.code == 'unavailable') {
      return NetworkFailure(message: e.code, cause: e);
    }
    return UnknownFailure(message: e.code, cause: e);
  }
}

final coachRequestRepositoryProvider = Provider<CoachRequestRepository>((ref) {
  return CoachRequestRepositoryImpl(ref.watch(firestoreProvider));
});
