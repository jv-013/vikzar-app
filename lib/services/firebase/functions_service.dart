import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The one place `FirebaseFunctions.instance` is called, mirroring
/// `firestore_service.dart`'s pattern (FLUTTER_ARCHITECTURE.md §6).
/// Phase 13 §5 is this app's first Flutter-side Cloud Functions caller
/// (`createPlannedSession`) — every prior Callable was laptop-only.
final functionsProvider = Provider<FirebaseFunctions>((ref) {
  return FirebaseFunctions.instance;
});
