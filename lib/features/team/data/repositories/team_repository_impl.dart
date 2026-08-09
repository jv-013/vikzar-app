import 'package:cloud_firestore/cloud_firestore.dart';
// `cloud_functions` also exports a `Result` type, colliding with this
// codebase's own `core/result/result.dart` — hidden here since only
// `FirebaseFunctions` is needed, matching `PlannedSessionRepositoryImpl`'s
// own import.
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/cloud_function_failure_mapper.dart';
import '../../../../core/errors/firestore_failure_mapper.dart';
import '../../../../core/result/result.dart';
import '../../../../services/firebase/firestore_service.dart';
import '../../../../services/firebase/functions_service.dart';
import '../../domain/models/team.dart';
import '../../domain/repositories/team_repository.dart';

class TeamRepositoryImpl implements TeamRepository {
  TeamRepositoryImpl(this._firestore, this._functions);

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _teams => _firestore.collection('teams');

  @override
  Future<Result<({String teamId, String inviteCode})>> createTeam({
    required String name,
    String? ageGroup,
  }) async {
    try {
      final callable = _functions.httpsCallable('createTeam');
      final response = await callable.call<Map<String, dynamic>>({
        'name': name,
        if (ageGroup != null && ageGroup.trim().isNotEmpty) 'ageGroup': ageGroup,
      });
      final teamId = response.data['teamId'] as String;
      final inviteCode = response.data['inviteCode'] as String;
      return Result.success((teamId: teamId, inviteCode: inviteCode));
    } catch (e) {
      return Result.failure(mapCloudFunctionError(e));
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
  Future<Result<void>> joinTeamAsCoach({required String teamId}) async {
    try {
      final callable = _functions.httpsCallable('joinTeamAsCoach');
      await callable.call<Map<String, dynamic>>({'teamId': teamId});
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapCloudFunctionError(e));
    }
  }

  @override
  Future<Result<String>> createTeamInvite({
    required String teamId,
    bool regenerate = false,
  }) async {
    try {
      final callable = _functions.httpsCallable('createTeamInvite');
      final response = await callable.call<Map<String, dynamic>>({
        'teamId': teamId,
        if (regenerate) 'regenerate': true,
      });
      return Result.success(response.data['inviteCode'] as String);
    } catch (e) {
      return Result.failure(mapCloudFunctionError(e));
    }
  }

  @override
  Future<Result<String>> joinTeamWithInvite({required String inviteCode}) async {
    try {
      final callable = _functions.httpsCallable('joinTeamWithInvite');
      final response = await callable.call<Map<String, dynamic>>({'inviteCode': inviteCode});
      return Result.success(response.data['teamId'] as String);
    } catch (e) {
      return Result.failure(mapCloudFunctionError(e));
    }
  }

  @override
  Stream<Result<List<TeamMember>>> watchRoster(String teamId) async* {
    try {
      await for (final snapshot in _teams.doc(teamId).collection('members').snapshots()) {
        yield Result.success([
          for (final doc in snapshot.docs) TeamMember.fromMap(doc.data(), uid: doc.id),
        ]);
      }
    } catch (e) {
      yield Result.failure(mapFirestoreError(e));
    }
  }
}

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  return TeamRepositoryImpl(ref.watch(firestoreProvider), ref.watch(functionsProvider));
});
