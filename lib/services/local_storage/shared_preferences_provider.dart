import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one place `SharedPreferences` is referenced as a bare instance.
/// Overridden in `app/bootstrap.dart` after `SharedPreferences.getInstance()`
/// resolves, so the rest of the app can read it synchronously — the
/// standard Riverpod pattern for a dependency that must be awaited exactly
/// once, at startup.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in app/bootstrap.dart '
    'after awaiting SharedPreferences.getInstance().',
  );
});
