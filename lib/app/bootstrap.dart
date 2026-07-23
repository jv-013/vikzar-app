import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../services/firebase/app_check_service.dart';
import '../services/local_storage/shared_preferences_provider.dart';
import 'app.dart';

/// App bootstrap, per FLUTTER_ARCHITECTURE.md §1 and §14.
///
/// Firebase is initialized against the **real, production Firebase
/// project** (`vikzar-prod`), connected at Phase 8A via `flutterfire
/// configure` — `firebase_options.dart` is FlutterFire-CLI-generated, not
/// hand-written (see DECISIONS.md ADR-050 for how the connection was
/// made, and ADR-042 for the placeholder era this supersedes).
///
/// **`firestore.rules`/`storage.rules` are authored in this repository
/// (Phase 8B) but not deployed to the Firebase Console.** Confirmed via
/// live testing at Phase 8C (DECISIONS.md ADR-054): the live project
/// still runs its original default-deny rules, so every Firestore call
/// currently fails with `permission-denied` until a project owner runs
/// the deploy themselves. No Cloud Functions exist either. Every
/// repository still maps every such failure to a calm `Failure` state,
/// never a crash — but a `permission-denied` failure is the *expected*,
/// reproducible result of every write today, not a rare edge case.
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
    // Phase 13 §9 — see app_check_service.dart for exactly what this
    // does and does not do yet (not yet enforced anywhere).
    await activateAppCheck();
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
