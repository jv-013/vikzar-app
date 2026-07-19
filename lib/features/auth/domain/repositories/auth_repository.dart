import '../../../../core/result/result.dart';
import '../models/auth_state.dart';

/// Identity gate contract, per ARCHITECTURE.md §9 and
/// FLUTTER_ARCHITECTURE.md §7. Phase 6: passwordless — email, then a
/// 6-digit one-time code. There is no password, confirm-password, or
/// forgot-password concept anywhere in this contract or above it.
abstract interface class AuthRepository {
  /// Backs the router's redirect logic (`routing/route_guards.dart`) and
  /// the app-lifetime "Global" `authStateProvider`, per
  /// FLUTTER_ARCHITECTURE.md §5.
  Stream<AuthState> get authStateChanges;

  /// Step 1 of the identity gate: requests a 6-digit code for [email].
  /// Never reveals whether the email belongs to an existing account —
  /// that distinction is resolved silently inside [verifyOtp].
  Future<Result<void>> sendOtp({required String email});

  /// Step 2: verifies [code] for [email]. Signs in if the account exists,
  /// transparently creates it if it doesn't — matching the frozen
  /// one-continuous-flow wireframe rather than exposing a separate
  /// "sign up" path the UI never offers.
  Future<Result<void>> verifyOtp({required String email, required String code});

  Future<Result<void>> signOut();
}
