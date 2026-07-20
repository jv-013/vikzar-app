import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../services/local_storage/shared_preferences_provider.dart';
import 'app.dart';

/// App bootstrap, per FLUTTER_ARCHITECTURE.md §1 and §14.
///
/// Firebase is initialized against the **real, production Firebase
/// project** (`vikzar-prod`), connected at Phase 8A via `flutterfire
/// configure` — `firebase_options.dart` is FlutterFire-CLI-generated, not
/// hand-written (see DECISIONS.md ADR-050 for how the connection was
/// made, and ADR-042 for the placeholder era this supersedes). No
/// Firestore Security Rules, Cloud Functions, or Authentication provider
/// configuration exist in the Firebase Console yet — those remain later
/// phases' work — so calls that reach Firebase may still fail (e.g.
/// `permission-denied` until rules are deployed), and every repository
/// still maps that to a `Failure` and a calm error state, never a crash.
///
/// The three-flavor `main_development.dart` / `main_staging.dart` /
/// `main_production.dart` split from FLUTTER_ARCHITECTURE.md §14 remains
/// deferred until separate environment-specific Firebase projects exist —
/// still a single `main.dart` calling this function against the one
/// `vikzar-prod` project.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    // Guards against genuine transient/environment failures (e.g. no
    // network on first launch, a platform's native config file not yet
    // synced) so a Firebase outage can never prevent the app from
    // launching — Authentication screens still render; any action that
    // actually needs Firebase fails with a calm error at the point of use
    // instead.
    debugPrint('Firebase.initializeApp failed: $error');
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
