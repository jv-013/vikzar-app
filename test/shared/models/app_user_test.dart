import 'package:flutter_test/flutter_test.dart';

import 'package:vikzar/shared/models/app_user.dart';
import 'package:vikzar/shared/models/workspace_type.dart';

void main() {
  group('AppUser.fromMap', () {
    test('parses a full users/{uid} document, per BACKEND_SPECIFICATION.md §1.5', () {
      final user = AppUser.fromMap(const {
        'email': 'jordan.blake@example.com',
        'displayName': 'Jordan Blake',
        'workspaces': {
          'player': {'teamId': 'team_riverside_u18'},
          'coach': {
            'teamIds': ['team_a', 'team_b'],
          },
        },
        'defaultWorkspace': 'player',
        'status': 'active',
      }, uid: 'uid_123');

      expect(user.uid, 'uid_123');
      expect(user.email, 'jordan.blake@example.com');
      expect(user.displayName, 'Jordan Blake');
      expect(user.workspaces.player!.teamId, 'team_riverside_u18');
      expect(user.workspaces.coach!.teamIds, ['team_a', 'team_b']);
      expect(user.defaultWorkspace, WorkspaceType.player);
      expect(user.status, 'active');
    });

    test('parses a brand-new account with no workspaces yet', () {
      final user = AppUser.fromMap(const {
        'email': 'new@vikzar.app',
      }, uid: 'uid_new');

      expect(user.workspaces.isEmpty, isTrue);
      expect(user.defaultWorkspace, isNull);
      expect(user.status, 'active'); // documented default
    });

    test('parses a Player-only workspace with no team yet (teamId null)', () {
      final user = AppUser.fromMap(const {
        'email': 'p@vikzar.app',
        'workspaces': {
          'player': {'teamId': null},
        },
        'defaultWorkspace': 'player',
      }, uid: 'uid_p');

      expect(user.workspaces.has(WorkspaceType.player), isTrue);
      expect(user.workspaces.player!.teamId, isNull);
      expect(user.workspaces.has(WorkspaceType.coach), isFalse);
    });
  });
}
