import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../design_system/components/vikzar_list_row.dart';
import '../../../../design_system/components/vikzar_section_header.dart';
import '../../../../design_system/tokens/spacing.dart';
import '../../../../shared/models/workspace_type.dart';
import '../../../../shared/providers/current_app_user_provider.dart';
import '../../../../shared/providers/current_uid_provider.dart';
import '../../../auth/data/repositories/auth_repository_impl.dart';
import '../../../auth/domain/models/auth_state.dart';
import '../../../raz/data/providers/raz_call_metrics_provider.dart';
import '../../../raz/domain/models/raz_message.dart';
import '../../../raz/domain/repositories/raz_repository.dart';
import '../../../raz/domain/repositories/raz_voice_permissions.dart';
import '../../../raz/presentation/controllers/raz_conversation_controller.dart';
import '../../../raz/presentation/controllers/raz_voice_controller.dart';
import '../../../raz/presentation/controllers/raz_voice_settings_controller.dart';
import '../../data/firestore_connectivity_provider.dart';

final _diagnosticsAppVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

/// Hidden, developer-only — never linked from any user-facing navigation.
/// Reached only via a long-press on Profile's App Version row, and only
/// ever registered as a route in debug builds (see `app_router.dart`),
/// so this entire screen and its route are compiled out of release/
/// App Store/Play Store builds. Purpose: rapid debugging during hardware
/// integration, not a user feature (Phase 20.5 Part 4).
///
/// Scoped to the [workspace] the developer long-pressed from — mirrors
/// Settings/RAZ's own per-workspace pattern, and deliberately avoids
/// waking the *other* workspace's live voice/conversation controllers
/// just to populate a debug screen.
class DiagnosticsScreen extends ConsumerWidget {
  const DiagnosticsScreen({super.key, required this.workspace});

  final WorkspaceType workspace;

  RazAudience get _audience => workspace == WorkspaceType.player ? RazAudience.player : RazAudience.coach;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = ref.watch(currentAppUserProvider);
    final uid = ref.watch(currentUidProvider);
    final firestoreConnectivity = ref.watch(firestoreConnectivityProvider);
    final lastCall = ref.watch(razCallMetricsProvider);
    final voiceState = ref.watch(razVoiceControllerProvider(_audience));
    final voiceSettings = ref.watch(razVoiceSettingsControllerProvider);
    final conversation = ref.watch(razConversationControllerProvider(_audience));
    final versionAsync = ref.watch(_diagnosticsAppVersionProvider);

    final lastRazMessage = conversation.messages.reversed
        .where((m) => m.sender == RazSender.raz)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Developer Diagnostics')),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: SpacingTokens.space8),
            const VikzarSectionHeader('Authentication'),
            VikzarListRow(
              title: 'Status',
              subtitle: authState.when(
                data: (state) => switch (state) {
                  Authenticated(:final uid, :final email) =>
                    'Signed in — uid=$uid${email != null ? ', $email' : ''}',
                  Unauthenticated() => 'Signed out',
                },
                loading: () => 'Loading…',
                error: (e, _) => 'Error: $e',
              ),
            ),
            const VikzarSectionHeader('Current User'),
            VikzarListRow(
              title: 'users/{uid} document',
              subtitle: user == null
                  ? (uid == null ? 'Not signed in' : 'No document loaded yet')
                  : '${(user.displayName ?? '').isEmpty ? '(no name)' : user.displayName} — '
                        'workspaces: ${user.workspaces.held.map((w) => w.label).join(", ")}',
            ),
            const VikzarSectionHeader('Firestore'),
            VikzarListRow(
              title: 'Connectivity',
              subtitle: firestoreConnectivity.when(
                data: (value) => switch (value) {
                  FirestoreConnectivity.live => 'Live — last snapshot came from the server',
                  FirestoreConnectivity.cached => 'Cached — served from on-device persistence',
                  FirestoreConnectivity.unknown => 'Unknown — not signed in',
                },
                loading: () => 'Checking…',
                error: (e, _) => 'Error: $e',
              ),
            ),
            const VikzarSectionHeader('Cloud Functions'),
            VikzarListRow(
              title: 'Last RAZ call',
              subtitle: lastCall == null
                  ? 'No call made yet this session'
                  : '${lastCall.callableName} — ${lastCall.latency.inMilliseconds}ms — '
                        '${lastCall.success ? 'success' : 'failed'}',
            ),
            const VikzarSectionHeader('Voice'),
            VikzarListRow(
              title: 'Voice status',
              subtitle:
                  'listening=${voiceState.isListening} thinking=${voiceState.isThinking} '
                  'speaking=${voiceState.isSpeaking}',
            ),
            VikzarListRow(
              title: 'Permission',
              subtitle: _permissionLabel(voiceState.permissionStatus),
            ),
            VikzarListRow(
              title: 'Wake word',
              subtitle:
                  '${voiceSettings.wakeWordEnabled ? 'enabled in Settings' : 'off (default)'} — '
                  'armed=${voiceState.wakeWordArmed}',
            ),
            const VikzarSectionHeader('Conversation'),
            VikzarListRow(
              title: '${workspace.label} thread',
              subtitle:
                  '${conversation.messages.length} message(s), '
                  'loading=${conversation.isLoading}'
                  '${conversation.errorText != null ? ', error: ${conversation.errorText}' : ''}',
            ),
            const VikzarSectionHeader('RAZ Awareness'),
            VikzarListRow(
              title: 'Last response',
              subtitle: lastRazMessage?.response == null
                  ? 'No RAZ interaction yet this session'
                  : 'awareness level ${lastRazMessage!.response!.awareness.level}, '
                        'confidence ${lastRazMessage.response!.confidence.name}',
            ),
            VikzarListRow(
              title: 'Reasoning provider',
              subtitle: 'Not exposed to the client, by design — RAZ never reveals which '
                  'model answered (RAZ_VOICE_ARCHITECTURE.md).',
            ),
            const VikzarSectionHeader('Notifications'),
            const VikzarListRow(
              title: 'Push notifications',
              subtitle: 'Not implemented yet — no firebase_messaging dependency exists.',
            ),
            const VikzarSectionHeader('Hardware'),
            const VikzarListRow(title: 'BLE Pod', subtitle: 'Not connected — no pairing pipeline yet'),
            const VikzarListRow(title: 'EMG', subtitle: 'Not connected — no sensor pipeline yet'),
            const VikzarListRow(title: 'GPS', subtitle: 'Not connected — no location pipeline yet'),
            const VikzarSectionHeader('App'),
            VikzarListRow(
              title: 'Version',
              subtitle: versionAsync.when(
                data: (v) => v,
                loading: () => '—',
                error: (_, _) => 'Unavailable',
              ),
            ),
            const VikzarListRow(title: 'Environment', subtitle: 'Single environment — no flavor split exists'),
            const VikzarListRow(title: 'Feature flags', subtitle: 'None — no feature-flag system exists yet'),
            const SizedBox(height: SpacingTokens.space32),
          ],
        ),
      ),
    );
  }

  String _permissionLabel(RazPermissionStatus? status) => switch (status) {
    null => 'Not checked yet',
    RazPermissionStatus.granted => 'Granted',
    RazPermissionStatus.denied => 'Denied',
    RazPermissionStatus.permanentlyDenied => 'Permanently denied',
    RazPermissionStatus.unsupported => 'Unsupported on this platform',
  };
}
