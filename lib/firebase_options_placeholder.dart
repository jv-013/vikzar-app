import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// **Placeholder Firebase configuration — pending Phase 8A completion.**
///
/// No real Firebase project is connected yet. Doing so requires the
/// project owner's own Firebase account (`firebase login`) and an
/// interactive project-selection step (`flutterfire configure`) — neither
/// is something this codebase can do on its own, and guessing a project
/// ID/API key would be worse than an honest placeholder. Every value below
/// is well-formed but fake, structured exactly as the FlutterFire CLI
/// would generate it, so the swap is small once it's run:
///
/// 1. `flutterfire configure` (see DECISIONS.md ADR-050 for the exact
///    commands and prerequisites) generates `lib/firebase_options.dart`,
///    exporting `DefaultFirebaseOptions`.
/// 2. In `app/bootstrap.dart`, change the import from
///    `firebase_options_placeholder.dart` to `firebase_options.dart` and
///    `PlaceholderFirebaseOptions.currentPlatform` to
///    `DefaultFirebaseOptions.currentPlatform`.
/// 3. Delete this file.
///
/// **Consequence until then:** any call that reaches Firebase (sign-in,
/// Firestore reads/writes) fails against these credentials. That failure
/// is expected and handled — every repository maps it to a `Failure` and
/// the UI shows the calm, standard error state
/// (`core/errors/failure_message_mapper.dart`) — not a crash. Flagged in
/// `README.md`, `CHANGELOG.md`, and this file so it is never mistaken for
/// a working backend.
abstract final class PlaceholderFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web; // no native Firebase SDK for these desktop targets;
      // the web configuration is used as the cross-platform fallback,
      // matching FlutterFire CLI's own convention for unsupported
      // desktop platforms.
    }
  }

  static const web = FirebaseOptions(
    apiKey: 'placeholder-api-key',
    appId: '1:000000000000:web:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'vikzar-placeholder',
    authDomain: 'vikzar-placeholder.firebaseapp.com',
    storageBucket: 'vikzar-placeholder.appspot.com',
  );

  static const android = FirebaseOptions(
    apiKey: 'placeholder-api-key',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'vikzar-placeholder',
    storageBucket: 'vikzar-placeholder.appspot.com',
  );

  static const ios = FirebaseOptions(
    apiKey: 'placeholder-api-key',
    appId: '1:000000000000:ios:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'vikzar-placeholder',
    storageBucket: 'vikzar-placeholder.appspot.com',
    iosBundleId: 'com.vikzar.vikzar',
  );

  static const macos = FirebaseOptions(
    apiKey: 'placeholder-api-key',
    appId: '1:000000000000:macos:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: 'vikzar-placeholder',
    storageBucket: 'vikzar-placeholder.appspot.com',
    iosBundleId: 'com.vikzar.vikzar',
  );
}
