import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options_placeholder.dart';
import '../services/local_storage/shared_preferences_provider.dart';
import 'app.dart';

/// App bootstrap, per FLUTTER_ARCHITECTURE.md §1 and §14.
///
/// Firebase is initialized against **placeholder credentials**
/// (`firebase_options_placeholder.dart`) — connecting the real, production
/// Firebase project is Phase 8A's explicit scope, but completing it
/// requires the project owner's own `firebase login` and an interactive
/// `flutterfire configure` run this codebase cannot perform on its own
/// (see DECISIONS.md ADR-050 for the exact commands). This is a
/// deliberate, documented limitation, not an oversight: every Firebase
/// call in this app is written to fail gracefully (mapped to a `Failure`,
/// shown as a calm error state) against these credentials, never to crash.
/// Swapping in the real, generated configuration once it exists is a
/// two-line change — see `firebase_options_placeholder.dart`'s doc comment.
///
/// The three-flavor `main_development.dart` / `main_staging.dart` /
/// `main_production.dart` split from FLUTTER_ARCHITECTURE.md §14 remains
/// deferred until real, environment-specific Firebase projects exist —
/// still a single `main.dart` calling this function.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: PlaceholderFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    // Placeholder credentials may cause initialization itself to fail on
    // some platforms/SDK versions, not just later network calls. Caught
    // here so a missing/invalid Firebase project can never prevent the
    // app from launching — Authentication screens still render; any
    // action that actually needs Firebase will fail with a calm error at
    // the point of use instead.
    debugPrint('Firebase.initializeApp failed (placeholder config): $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const VikzarApp(),
    ),
  );
}
