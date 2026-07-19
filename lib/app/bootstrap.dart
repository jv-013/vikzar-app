import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

/// App bootstrap, per FLUTTER_ARCHITECTURE.md §1 and §14.
///
/// Phase 4 (bootstrap) scope: this is deliberately minimal. The full
/// bootstrap sequence FLUTTER_ARCHITECTURE.md describes —
/// `Firebase.initializeApp` against an environment-specific
/// `FirebaseOptions`, wiring `FlutterError.onError` and
/// `PlatformDispatcher.instance.onError` to Crashlytics (§12, §13), and
/// selecting a flavor (`Environment.development` / `.staging` /
/// `.production`, §14) — is not implemented here, because no Firebase
/// project exists yet to configure against (creating one is an
/// infrastructure/account action outside this phase's scope, and
/// explicitly outside what "Do NOT implement Firebase logic" permits).
///
/// This function is the single, stable seam that later phases extend:
/// `main_development.dart` / `main_staging.dart` / `main_production.dart`
/// (§14) will each call `bootstrap(Environment.x)` once that work begins;
/// today, [main.dart] calls this directly with no argument.
void bootstrap() {
  runApp(const ProviderScope(child: VikzarApp()));
}
