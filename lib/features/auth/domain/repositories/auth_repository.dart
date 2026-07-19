import '../../../../core/result/result.dart';
import '../models/auth_state.dart';

/// Identity gate contract, per ARCHITECTURE.md §9 and
/// FLUTTER_ARCHITECTURE.md §7. MVP scope: email/password only —
/// DESIGN_SPECIFICATION.md §19.1's single Sign In / Create Account screen,
/// no Google/Apple sign-in.
abstract interface class AuthRepository {
  /// Backs the router's redirect logic (`routing/route_guards.dart`) and
  /// the app-lifetime "Global" `authStateProvider`, per
  /// FLUTTER_ARCHITECTURE.md §5.
  Stream<AuthState> get authStateChanges;

  /// The single "Continue" action on the Sign In / Create Account screen:
  /// signs in if the account exists, transparently creates it if it
  /// doesn't — matching the frozen one-screen, one-action wireframe rather
  /// than exposing a separate "sign up" flow the UI never offers.
  Future<Result<void>> signInOrCreateAccount({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();
}
