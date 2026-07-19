import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/shared/models/user_workspaces.dart';
import 'package:vikzar/shared/models/workspace_type.dart';

void main() {
  group('WorkspaceType', () {
    test('firestoreKey round-trips through fromFirestoreKey', () {
      for (final type in WorkspaceType.values) {
        expect(WorkspaceType.fromFirestoreKey(type.firestoreKey), type);
      }
    });

    test('fromFirestoreKey returns null for an unknown or null key', () {
      expect(WorkspaceType.fromFirestoreKey('clinician'), isNull);
      expect(WorkspaceType.fromFirestoreKey(null), isNull);
    });
  });

  group('UserWorkspaces', () {
    test('empty has no held workspaces', () {
      const workspaces = UserWorkspaces.empty();

      expect(workspaces.isEmpty, isTrue);
      expect(workspaces.held, isEmpty);
      expect(workspaces.has(WorkspaceType.player), isFalse);
      expect(workspaces.has(WorkspaceType.coach), isFalse);
    });

    test('a player-only account holds exactly Player', () {
      const workspaces = UserWorkspaces(player: PlayerWorkspace(teamId: 'team_1'));

      expect(workspaces.isEmpty, isFalse);
      expect(workspaces.held, [WorkspaceType.player]);
      expect(workspaces.has(WorkspaceType.player), isTrue);
      expect(workspaces.has(WorkspaceType.coach), isFalse);
    });

    test('an account holding both workspaces reports both, in order', () {
      const workspaces = UserWorkspaces(
        player: PlayerWorkspace(teamId: 'team_1'),
        coach: CoachWorkspace(teamIds: ['team_2', 'team_3']),
      );

      expect(workspaces.held, [WorkspaceType.player, WorkspaceType.coach]);
      expect(workspaces.coach!.teamIds, ['team_2', 'team_3']);
    });
  });
}
