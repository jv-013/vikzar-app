import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// **Placeholder Firebase configuration.**
///
/// No Firebase project exists yet — creating one requires Firebase/GCP
/// console access this session does not have (an infrastructure/account
/// action, not a code one; see BACKEND_SPECIFICATION.md §3's ingestion
/// principal for the same class of "out of this repository's scope" note).
/// Per this phase's explicit instruction — "use placeholder Firebase
/// configuration if production credentials are unavailable" — every value
/// below is a well-formed but fake placeholder, structured exactly as the
/// FlutterFire CLI (`flutterfire configure`) would generate it, so
/// replacing this file with the real, generated one is a drop-in swap.
///
/// **Consequence:** any call that reaches Firebase (sign-in, Firestore
/// reads/writes) will fail against these credentials. That failure is
/// expected and handled — every repository maps it to a `Failure` and the
/// UI shows the calm, standard error state (`core/errors/failure_message_mapper.dart`)
/// — not a crash. This is a real, honest limitation of this phase, not a
/// bug: it is flagged in `README.md`, `CHANGELOG.md`, and this file so it
/// is never mistaken for a working backend.
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
