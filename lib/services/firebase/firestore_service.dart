import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one place `FirebaseFirestore.instance` is called, per
/// FLUTTER_ARCHITECTURE.md §6 — every other file obtains it via this
/// provider. Deliberately no business logic here; business-relevant
/// Firestore access lives in each repository's `data/datasources`
/// (`shared/repositories` for cross-feature ones like `UserRepository`).
///
/// **Revised at Phase 8B:** enables offline persistence
/// (`Settings.persistenceEnabled`), per BACKEND_SPECIFICATION.md §19's
/// "Firestore's built-in offline persistence handles structured-data reads
/// and the small set of permitted client writes... while the app is
/// offline, syncing automatically on reconnect." This is on by default on
/// mobile/desktop but must be set explicitly for Flutter Web, so it's set
/// here unconditionally rather than branching on `kIsWeb` — a harmless,
/// already-default no-op on the other platforms.
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final firestore = FirebaseFirestore.instance;
  firestore.settings = const Settings(persistenceEnabled: true);
  return firestore;
});
