import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/firestore_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../../../services/firebase/firestore_service.dart';
import '../../domain/models/team.dart';
import '../../domain/repositories/team_repository.dart';

class TeamRepositoryImpl implements TeamRepository {
  TeamRepositoryImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _teams =>
      _firestore.collection('teams');

  @override
  Future<Result<String>> createTeam({
    required String coachUid,
    required String name,
    String? ageGroup,
  }) async {
    try {
      final docRef = _teams.doc();
      await docRef.set({
        'teamId': docRef.id,
        'name': name,
        if (ageGroup != null && ageGroup.trim().isNotEmpty) 'ageGroup': ageGroup,
        'coachIds': [coachUid],
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return Result.success(docRef.id);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<Team?>> getTeam(String teamId) async {
    try {
      final snapshot = await _teams.doc(teamId).get();
      final data = snapshot.data();
      if (data == null) return const Result.success(null);
      return Result.success(Team.fromMap(data, teamId: teamId));
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<void>> joinTeamAsCoach({
    required String teamId,
    required String coachUid,
  }) async {
    try {
      final docRef = _teams.doc(teamId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        return const Result.failure(
          CloudFailure(message: 'team-not-found'),
        );
      }
      await docRef.update({
        'coachIds': FieldValue.arrayUnion([coachUid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Future<Result<void>> joinTeamAsPlayer({
    required String teamId,
    required String uid,
    required String displayName,
    String? avatarUrl,
  }) async {
    try {
      final teamDoc = await _teams.doc(teamId).get();
      if (!teamDoc.exists) {
        return const Result.failure(
          CloudFailure(message: 'team-not-found'),
        );
      }
      await _teams.doc(teamId).collection('members').doc(uid).set({
        'uid': uid,
        'displayName': displayName,
        'avatarUrl': ?avatarUrl,
        'role': 'player',
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirestoreError(e));
    }
  }

  @override
  Stream<Result<List<TeamMember>>> watchRoster(String teamId) async* {
    try {
      await for (final snapshot
          in _teams.doc(teamId).collection('members').snapshots()) {
        yield Result.success([
          for (final doc in snapshot.docs)
            TeamMember.fromMap(doc.data(), uid: doc.id),
        ]);
      }
    } catch (e) {
      yield Result.failure(mapFirestoreError(e));
    }
  }
}

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepositoryImpl(ref.watch(firestoreProvider));
});
