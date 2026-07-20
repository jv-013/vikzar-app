import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/firestore_failure_mapper.dart';
import '../../core/result/result.dart';
import '../../services/firebase/firestore_service.dart';
import '../models/app_user.dart';
import '../models/coach_profile.dart';
import '../models/player_profile.dart';
import '../models/workspace_type.dart';
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
    } catch (e) {
      yield Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<void>> completePlayerOnboarding({
    required String uid,
    required String email,
    required String displayName,
    required PlayerProfile profile,
    String? teamId,
  }) => _completeOnboarding(
    uid: uid,
    email: email,
    displayName: displayName,
    workspace: WorkspaceType.player,
    workspaceMap: {'teamId': teamId},
    profileField: 'playerProfile',
    profileMap: profile.toMap(),
  );

  @override
  Future<Result<void>> completeCoachOnboarding({
    required String uid,
    required String email,
    required String displayName,
    required CoachProfile profile,
    required String teamId,
  }) => _completeOnboarding(
    uid: uid,
    email: email,
    displayName: displayName,
    workspace: WorkspaceType.coach,
    workspaceMap: {
      'teamIds': [teamId],
    },
    profileField: 'coachProfile',
    profileMap: profile.toMap(),
  );

  /// Shared onboarding-completion transaction: creates or merges
  /// `users/{uid}`, writes `workspaces.{workspace}`, the workspace's
  /// profile map, `displayName`, `email`, and — only if the document
  /// doesn't already have one — `defaultWorkspace`. A transaction (rather
  /// than a plain merge-set) is required specifically because "set
  /// `defaultWorkspace` only if absent" depends on reading the current
  /// document first.
  Future<Result<void>> _completeOnboarding({
    required String uid,
    required String email,
    required String displayName,
    required WorkspaceType workspace,
    required Map<String, dynamic> workspaceMap,
    required String profileField,
    required Map<String, dynamic> profileMap,
  }) async {
    try {
      final docRef = _firestore.collection('users').doc(uid);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        final existing = snapshot.data();
        final now = FieldValue.serverTimestamp();
        final update = <String, dynamic>{
          'uid': uid,
          'email': email,
          'displayName': displayName,
          'workspaces.${workspace.firestoreKey}': workspaceMap,
          profileField: profileMap,
          'status': existing?['status'] as String? ?? 'active',
          'updatedAt': now,
        };
        if (existing == null) {
          update['createdAt'] = now;
        }
        if (existing == null || existing['defaultWorkspace'] == null) {
          update['defaultWorkspace'] = workspace.firestoreKey;
        }
        transaction.set(docRef, update, SetOptions(merge: true));
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<void>> updateDisplayName({
    required String uid,
    required String displayName,
  }) => _merge(uid, {
    'displayName': displayName,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<Result<void>> updatePlayerProfile({
    required String uid,
    required PlayerProfile profile,
  }) => _merge(uid, {
    'playerProfile': profile.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<Result<void>> updateCoachProfile({
    required String uid,
    required CoachProfile profile,
  }) => _merge(uid, {
    'coachProfile': profile.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  Future<Result<void>> _merge(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
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
