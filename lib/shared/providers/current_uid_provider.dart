import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/models/auth_state.dart';

/// The currently authenticated Firebase UID, or `null` when signed out —
/// derived from [authStateProvider]. Per DECISIONS.md ADR-052, every piece
/// of purely-local (`SharedPreferences`-backed) per-account state must be
/// scoped by this value, never by a single fixed key, so signing out of one
/// account and into another can never read the previous account's cached
/// local state.
final currentUidProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return switch (authState) {
    Authenticated(:final uid) => uid,
    _ => null,
  };
});

/// The authenticated account's email, straight from Firebase Auth — used
/// where `users/{uid}.email` must be written but the Firestore document
/// (and therefore [currentAppUserProvider]) may not exist yet, e.g. the
/// very first write onboarding completion makes.
final currentUserEmailProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return switch (authState) {
    Authenticated(:final email) => email,
    _ => null,
  };
});
