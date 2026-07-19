import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/failure.dart';
import '../../core/result/result.dart';
import '../../services/firebase/firestore_service.dart';
import '../models/app_user.dart';
import 'user_repository.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Stream<Result<AppUser?>> watchUser(String uid) async* {
    try {
      await for (final snapshot
          in _firestore.collection('users').doc(uid).snapshots()) {
        final data = snapshot.data();
        if (data == null) {
          yield const Result.success(null);
        } else {
          yield Result.success(AppUser.fromMap(data, uid: uid));
        }
      }
    } on FirebaseException catch (e) {
      yield Result.failure(_mapException(e));
    } catch (e) {
      yield Result.failure(UnknownFailure(cause: e));
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

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepositoryImpl(ref.watch(firestoreProvider));
});

/// Watches one `users/{uid}` document. Family-scoped since the uid is only
/// known once authenticated — consumed by `routing/route_guards.dart`'s
/// `routeDestinationProvider`.
final watchUserProvider = StreamProvider.family<Result<AppUser?>, String>((
  ref,
  uid,
) {
  return ref.watch(userRepositoryProvider).watchUser(uid);
});
