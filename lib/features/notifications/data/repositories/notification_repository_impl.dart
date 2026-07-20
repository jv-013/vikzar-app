import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../services/firebase/firestore_service.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  @override
  Stream<Result<List<AppNotification>>> watchNotifications(String uid) async* {
    try {
      await for (final snapshot
          in _collection(
            uid,
          ).orderBy('createdAt', descending: true).snapshots()) {
        yield Result.success([
          for (final doc in snapshot.docs) AppNotification.fromMap(_normalize(doc.data()), id: doc.id),
        ]);
      }
    } on FirebaseException catch (e) {
      yield Result.failure(_mapException(e));
    } catch (e) {
      yield Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Converts Firestore's `Timestamp` (a `cloud_firestore` SDK type) into
  /// a plain `DateTime` before handing the map to [AppNotification.fromMap]
  /// — keeping the domain model itself free of any Firebase dependency,
  /// per FLUTTER_ARCHITECTURE.md §1's dependency rule.
  Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    return {
      ...data,
      'createdAt': createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
    };
  }

  @override
  Future<Result<void>> markAsRead({
    required String uid,
    required String notificationId,
  }) async {
    try {
      await _collection(uid).doc(notificationId).update({'read': true});
      return const Result.success(null);
    } on FirebaseException catch (e) {
      return Result.failure(_mapException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  @override
  Future<Result<void>> markAllAsRead({
    required String uid,
    required List<String> notificationIds,
  }) async {
    try {
      final batch = _firestore.batch();
      for (final id in notificationIds) {
        batch.update(_collection(uid).doc(id), {'read': true});
      }
      await batch.commit();
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

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(ref.watch(firestoreProvider));
});
