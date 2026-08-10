import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The SDK-boundary abstraction over `package:app_links`, per
/// FLUTTER_ARCHITECTURE.md §7/§15 — the same reasoning as
/// `features/auth/data/datasources/auth_datasource.dart` wrapping
/// `firebase_auth`: nothing above this interface touches the plugin
/// directly, so `AuthScreen` (the one consumer, for completing the
/// Firebase Email Link sign-in flow) stays testable with a plain fake
/// instead of a real platform channel.
abstract interface class DeepLinkService {
  /// The link the app was cold-started with, if any (e.g. tapped from
  /// a fully-closed state). Returns once, does not re-fire on later
  /// resumes — those come through [linkStream].
  Future<Uri?> getInitialLink();

  /// Links received while the app is already running (backgrounded or
  /// foregrounded).
  Stream<Uri> get linkStream;
}

class AppLinksDeepLinkService implements DeepLinkService {
  AppLinksDeepLinkService([AppLinks? appLinks]) : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get linkStream => _appLinks.uriLinkStream;
}

final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  return AppLinksDeepLinkService();
});
