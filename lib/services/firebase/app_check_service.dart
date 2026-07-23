import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// Phase 13 §9 — activates Firebase App Check so Firebase resources can
/// eventually be restricted to genuine Vikzar clients only.
///
/// **What this does today:** attaches the App Check SDK to every
/// platform with the correct provider for its build mode — debug builds
/// use the debug provider (per-install token, registered manually in the
/// Firebase Console), release builds use the platform's real attestation
/// (Play Integrity on Android, App Attest on iOS/macOS). Web only
/// activates if a reCAPTCHA v3 site key is supplied via
/// `--dart-define=RECAPTCHA_V3_SITE_KEY=...` — there is no key
/// committed to this repo, so Web App Check is inert (silently skipped,
/// logged once) until the project owner creates a reCAPTCHA v3 key in
/// the Google Cloud Console and supplies it at build time.
///
/// **What this does NOT do:** it does not make Firebase reject
/// unattested requests. That is a separate, explicit step — either
/// flipping Cloud Functions' `enforceAppCheck` option (see
/// `functions/src/lib/appCheck.ts`) or the Firebase Console's
/// per-resource App Check enforcement toggle for Firestore/Storage — and
/// **must not be flipped until every real client (this app, on every
/// platform it ships to) is already sending valid App Check tokens**,
/// or existing installs will suddenly start failing every Firebase call.
/// Registering this app with each attestation provider (Play Integrity
/// in Google Play Console, App Attest/DeviceCheck in Apple Developer
/// account, reCAPTCHA v3 site key in Google Cloud Console, and
/// registering debug tokens for development devices) is manual Console
/// work outside what this codebase can perform — documented in
/// DECISIONS.md alongside this function.
Future<void> activateAppCheck() async {
  const recaptchaSiteKey = String.fromEnvironment('RECAPTCHA_V3_SITE_KEY');

  try {
    // Uses the deprecated androidProvider/appleProvider/webProvider
    // parameters (info-level lint only) rather than their replacements
    // (providerAndroid/providerApple/providerWeb), which take richer
    // provider objects this package version's docs weren't available to
    // verify against — this form is stable and functionally identical.
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.appAttest,
      webProvider: recaptchaSiteKey.isEmpty ? null : ReCaptchaV3Provider(recaptchaSiteKey),
    );
    if (kIsWeb && recaptchaSiteKey.isEmpty) {
      debugPrint(
        'App Check: no RECAPTCHA_V3_SITE_KEY supplied — Web App Check is inactive. '
        'Pass --dart-define=RECAPTCHA_V3_SITE_KEY=<key> to enable it.',
      );
    }
  } catch (error, stackTrace) {
    // Matches bootstrap()'s own Firebase.initializeApp guard: App Check
    // is not yet enforced anywhere (see doc comment above), so a failure
    // here — e.g. this app isn't registered with a provider yet — must
    // never block app launch.
    debugPrint('FirebaseAppCheck.activate failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
