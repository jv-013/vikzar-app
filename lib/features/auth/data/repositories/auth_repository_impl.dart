import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/models/auth_state.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_datasource.dart';
import '../datasources/firebase_auth_datasource.dart';

/// Error codes across `firebase_auth` SDK versions that mean "no account
/// exists for this email" — newer versions consolidate several codes into
/// `invalid-credential` for enumeration-attack protection, so both are
/// checked.
const _noAccountErrorCodes = {'user-not-found', 'invalid-credential'};

final _otpFormat = RegExp(r'^\d{6}$');

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._datasource);

  final AuthDatasource _datasource;

  @override
  Stream<AuthState> get authStateChanges => _datasource.authStateChanges.map(
    (user) => user == null
        ? const Unauthenticated()
        : Authenticated(uid: user.uid, email: user.email),
  );

  @override
  Future<Result<void>> sendOtp({required String email}) async {
    try {
      await _datasource.sendOtp(email: email);
      return const Result.success(null);
    } on AuthDatasourceException catch (e) {
      return Result.failure(_mapException(e));
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// **Placeholder OTP verification (DECISIONS.md ADR-044).** No backend
  /// exists yet — no Cloud Function, no Firestore-stored codes, no email
  /// delivery — to generate and verify a real one-time code, and building
  /// one is explicitly out of this phase's scope (Firestore/Cloud
  /// Functions). So this method accepts any syntactically valid 6-digit
  /// [code] and, underneath, signs in (or transparently creates an
  /// account) against Firebase Auth's real email/password mechanism using
  /// a **secret deterministically derived from [email]** —
  /// [_deriveCredentialSecret] — never a value the user sees, types, or
  /// could reconstruct as a "password." This is what lets real Firebase
  /// session/UID/persistence semantics work correctly today (the same
  /// account, the same UID, across app restarts and devices) while the
  /// verification step itself remains honestly unverified.
  ///
  /// **Not safe for production as written.** Before this ships to real
  /// users, [code] must be checked against a real, time-limited,
  /// single-use code issued and verified server-side (a Cloud Function),
  /// and this placeholder derivation removed entirely — flagged here and
  /// in the Phase 6 CHANGELOG entry as a blocker for a future phase, not
  /// silently left as a permanent shortcut.
  @override
  Future<Result<void>> verifyOtp({
    required String email,
    required String code,
  }) async {
    if (!_otpFormat.hasMatch(code)) {
      return const Result.failure(AuthFailure(message: 'invalid-otp-format'));
    }

    final secret = _deriveCredentialSecret(email);
    try {
      await _datasource.signIn(email: email, secret: secret);
      return const Result.success(null);
    } on AuthDatasourceException catch (signInError) {
      if (!_noAccountErrorCodes.contains(signInError.code)) {
        return Result.failure(_mapException(signInError));
      }

      // No account for this email yet — the single continuous flow
      // (DESIGN_SPECIFICATION.md §19.1) transparently creates one rather
      // than sending the user to a separate sign-up path.
      try {
        await _datasource.createAccount(email: email, secret: secret);
        return const Result.success(null);
      } on AuthDatasourceException catch (createError) {
        if (createError.code == 'email-already-in-use') {
          // The account does exist after all — surface the original
          // sign-in failure rather than the confusing "already in use"
          // error (should not occur in practice, since the derived secret
          // is deterministic per email, but handled for the same
          // defensive reason Phase 5's password flow handled it).
          return Result.failure(_mapException(signInError));
        }
        return Result.failure(_mapException(createError));
      }
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _datasource.signOut();
      return const Result.success(null);
    } catch (e) {
      return Result.failure(UnknownFailure(cause: e));
    }
  }

  /// Deterministic per-email secret used only to drive Firebase Auth's
  /// email/password SDK methods internally — see [verifyOtp]'s doc
  /// comment. Salted with a fixed, non-secret app-level string so the
  /// derived value isn't simply the email itself; this is *not* a
  /// cryptographic security boundary (the whole point is that the real
  /// gate is the OTP step, once that step is real) and must not be treated
  /// as one.
  String _deriveCredentialSecret(String email) {
    final bytes = utf8.encode(
      'vikzar-otp-placeholder-v1::${email.trim().toLowerCase()}',
    );
    return sha256.convert(bytes).toString();
  }

  Failure _mapException(AuthDatasourceException e) {
    switch (e.code) {
      case 'network-request-failed':
        return NetworkFailure(message: e.code, cause: e);
      case 'invalid-email':
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-disabled':
        return AuthFailure(message: e.code, cause: e);
      default:
        return UnknownFailure(message: e.code, cause: e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(firebaseAuthDatasourceProvider));
});

/// Global-scope auth status, per FLUTTER_ARCHITECTURE.md §5 — the router's
/// redirect logic and any screen needing "am I signed in" watches this.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});
