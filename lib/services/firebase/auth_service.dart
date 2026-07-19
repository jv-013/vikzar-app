import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one place `FirebaseAuth.instance` is called, per
/// FLUTTER_ARCHITECTURE.md §6 — every other file obtains it via this
/// provider. Deliberately no logic here beyond exposing the SDK singleton;
/// business-relevant auth logic lives in `features/auth/data`.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});
