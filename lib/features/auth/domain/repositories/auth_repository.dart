import '../../../../core/result/result.dart';
import '../models/auth_state.dart';

/// Identity gate contract, per ARCHITECTURE.md §9 and
/// FLUTTER_ARCHITECTURE.md §7.
///
/// **Phase 17** replaces the passwordless email + 6-digit-code flow (see
/// DECISIONS.md ADR-044, now superseded) with three real Firebase
/// Authentication providers — there is no password, code, or
/// forgot-password concept anywhere in this contract or above it, and no
/// verification step that isn't Firebase's own.
abstract interface class AuthRepository {
  /// Backs the router's redirect logic (`routing/route_guards.dart`) and
  /// the app-lifetime "Global" `authStateProvider`, per
  /// FLUTTER_ARCHITECTURE.md §5.
  Stream<AuthState> get authStateChanges;

  /// Signs in with Google. Resolves to a plain success with no state
  /// change if the user cancels the account picker — cancellation is a
  /// normal outcome, not a failure the UI needs to display.
  Future<Result<void>> signInWithGoogle();

  /// Signs in with Apple. Only meaningfully offered on iOS/macOS — see
  /// `AuthScreen`. Same cancellation-is-not-a-failure treatment as
  /// [signInWithGoogle].
  Future<Result<void>> signInWithApple();

  /// Step 1 of the magic-link flow: emails [email] a Firebase sign-in
  /// link. Never reveals whether the email belongs to an existing
  /// account — Firebase Email Link sign-in creates one transparently if
  /// it doesn't, matching the single continuous flow the old OTP flow
  /// also used.
  Future<Result<void>> sendSignInLinkToEmail(String email);

  /// Whether [link] is a Firebase sign-in link at all.
  bool isSignInWithEmailLink(String link);

  /// Step 2: completes sign-in using the tapped link. [email] must be the
  /// address [sendSignInLinkToEmail] was called with.
  Future<Result<void>> signInWithEmailLink({required String email, required String emailLink});

  Future<Result<void>> signOut();
}
