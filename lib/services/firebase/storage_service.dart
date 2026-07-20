import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one place `FirebaseStorage.instance` is called, per
/// FLUTTER_ARCHITECTURE.md §6 — every other file obtains it via this
/// provider. Deliberately no logic here; business-relevant Storage access
/// (raw session exports, per BACKEND_SPECIFICATION.md §11) belongs to
/// whichever feature first needs it — added Phase 8A alongside
/// `auth_service.dart`/`firestore_service.dart` so all three Firebase
/// products this codebase depends on (Authentication, Firestore, Storage)
/// initialize identically; no repository reads from it yet.
final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});
