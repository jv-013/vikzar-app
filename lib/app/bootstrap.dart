import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options_placeholder.dart';
import '../services/local_storage/shared_preferences_provider.dart';
import 'app.dart';

/// App bootstrap, per FLUTTER_ARCHITECTURE.md §1 and §14.
///
/// Phase 5 adds real Firebase initialization and `SharedPreferences` setup
/// — both genuinely needed now that Authentication and the local-only
/// active-workspace store (DECISIONS.md ADR-031) exist. Firebase is
/// initialized against **placeholder credentials**
/// (`firebase_options_placeholder.dart`) since no real project exists yet
/// — per this phase's explicit instruction to use placeholder
/// configuration when production credentials are unavailable. This is a
/// deliberate, documented limitation, not an oversight: every Firebase
/// call in this app is written to fail gracefully (mapped to a `Failure`,
/// shown as a calm error state) against these credentials, never to crash.
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
