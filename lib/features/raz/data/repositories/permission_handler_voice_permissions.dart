import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart' as ph;

import '../../domain/repositories/raz_voice_permissions.dart';

/// The first real use of `permission_handler` anywhere in this app —
/// every other touchpoint before this phase (RAZ's original push-to-talk,
/// the onboarding permissions screen) either delegated to a plugin's own
/// implicit prompt or was non-functional placeholder UI. Voice OS is the
/// first place this app explicitly checks/requests a permission and
/// branches on denied vs. permanently-denied.
///
/// **macOS is not supported.** `permission_handler` registers no macOS
/// implementation for `Permission.microphone` (confirmed against its own
/// `pubspec.yaml` and `GeneratedPluginRegistrant.swift`) — calling it
/// unconditionally would throw `MissingPluginException` the moment a
/// macOS user opened Voice Mode. Checked explicitly rather than caught
/// generically, so this stays a declared platform gap, not a swallowed
/// crash.
class PermissionHandlerVoicePermissions implements RazVoicePermissions {
  bool get _isSupportedPlatform => !kIsWeb && !Platform.isMacOS;

  @override
  Future<RazPermissionStatus> check() async {
    if (!_isSupportedPlatform) return RazPermissionStatus.unsupported;
    return _map(await ph.Permission.microphone.status);
  }

  @override
  Future<RazPermissionStatus> request() async {
    if (!_isSupportedPlatform) return RazPermissionStatus.unsupported;
    final current = await ph.Permission.microphone.status;
    if (current.isGranted || current.isPermanentlyDenied) return _map(current);
    return _map(await ph.Permission.microphone.request());
  }

  @override
  Future<void> openSettings() async {
    if (!_isSupportedPlatform) return;
    await ph.openAppSettings();
  }

  RazPermissionStatus _map(ph.PermissionStatus status) {
    if (status.isGranted) return RazPermissionStatus.granted;
    if (status.isPermanentlyDenied) return RazPermissionStatus.permanentlyDenied;
    return RazPermissionStatus.denied;
  }
}
