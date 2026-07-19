import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one place `FirebaseFirestore.instance` is called, per
/// FLUTTER_ARCHITECTURE.md §6 — every other file obtains it via this
/// provider. Deliberately no logic here; business-relevant Firestore
/// access lives in each repository's `data/datasources`
/// (`shared/repositories` for cross-feature ones like `UserRepository`).
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});
