import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vikzar/design_system/theme/app_theme.dart';
import 'package:vikzar/features/profile/presentation/widgets/workspace_switch_sheet.dart';
import 'package:vikzar/features/workspace/presentation/controllers/active_workspace_controller.dart';
import 'package:vikzar/services/local_storage/shared_preferences_provider.dart';
import 'package:vikzar/shared/models/workspace_type.dart';
import 'package:vikzar/shared/providers/current_app_user_provider.dart';
import 'package:vikzar/shared/providers/current_uid_provider.dart';

const _uid = 'uid_123';

void main() {
  group('WorkspaceSwitchSheet', () {
    testWidgets(
      'lists only the workspaces the account holds, and switching updates '
      'the active workspace locally, instantly — no logout, no loading '
      'screen',
      (tester) async {
        SharedPreferences.setMockInitialValues({'active_workspace::$_uid': 'player'});
        final prefs = await SharedPreferences.getInstance();
        late final ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              currentUidProvider.overrideWithValue(_uid),
              heldWorkspacesProvider.overrideWithValue(const [
                WorkspaceType.player,
                WorkspaceType.coach,
              ]),
            ],
            child: Consumer(
              builder: (context, ref, _) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: AppTheme.dark(),
                  home: const Scaffold(body: WorkspaceSwitchSheet()),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Player'), findsOneWidget);
        expect(find.text('Coach'), findsOneWidget);
        expect(container.read(activeWorkspaceProvider), WorkspaceType.player);

        await tester.tap(find.text('Coach'));
        await tester.pumpAndSettle();

        expect(container.read(activeWorkspaceProvider), WorkspaceType.coach);
        expect(prefs.getString('active_workspace::$_uid'), 'coach');
      },
    );
  });
}
