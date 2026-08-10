import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart' as google;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../services/firebase/auth_service.dart';
import 'auth_datasource.dart';

/// The actual emailed sign-in link's host+path is Firebase's own
/// `/__/auth/links` on this domain, not this continue URL — this value
/// only becomes the `continueUrl` *parameter* carried through it, shown
/// on the web fallback page if the app couldn't be opened. Both
/// `hosting/.well-known/assetlinks.json` (Android Digital Asset Links)
/// and this continue page (`hosting/finishSignIn.html`) are deployed —
/// see DECISIONS.md's Phase 17 ADR for the Android App Links
/// verification this unlocks and the two other providers' remaining
/// project-owner gaps.
const _emailLinkContinueUrl = 'https://vikzar-prod.firebaseapp.com/finishSignIn';

/// The only file in `features/auth` permitted to import `firebase_auth`
/// (or the provider SDKs it delegates to) directly, per
/// FLUTTER_ARCHITECTURE.md §3/§7 — everything above this
/// (`AuthDatasource`, `data/repositories`, `presentation/`) works with
/// plain Dart types only, via the `AuthDatasource` interface.
class FirebaseAuthDatasource implements AuthDatasource {
  FirebaseAuthDatasource(this._auth);

  final fb.FirebaseAuth _auth;
  bool _googleSignInInitialized = false;

  @override
  Stream<AuthUser?> get authStateChanges => _auth.authStateChanges().map(
    (user) => user == null ? null : AuthUser(uid: user.uid, email: user.email),
  );

  @override
  Future<void> signInWithGoogle() async {
    try {
      if (!_googleSignInInitialized) {
        await google.GoogleSignIn.instance.initialize();
        _googleSignInInitialized = true;
      }
      final account = await google.GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AuthDatasourceException('google-sign-in-no-id-token');
      }
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      await _auth.signInWithCredential(credential);
    } on google.GoogleSignInException catch (e) {
      if (e.code == google.GoogleSignInExceptionCode.canceled) {
        throw const AuthDatasourceException('google-sign-in-cancelled');
      }
      throw AuthDatasourceException('google-sign-in-${e.code.name}');
    } on fb.FirebaseAuthException catch (e) {
      throw AuthDatasourceException(e.code);
    }
  }

  @override
  Future<void> signInWithApple() async {
    // A raw/hashed nonce pair (Firebase's own recommended pattern):
    // Apple never sees the raw value, only its SHA-256 hash, and
    // Firebase verifies the raw value against the ID token's embedded
    // hash — mitigates replay of a captured identity token.
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: hashedNonce,
      );
      final oauthCredential = fb.OAuthProvider('apple.com').credential(
        idToken: credential.identityToken,
        rawNonce: rawNonce,
        accessToken: credential.authorizationCode,
      );
      await _auth.signInWithCredential(oauthCredential);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthDatasourceException('apple-sign-in-cancelled');
      }
      throw AuthDatasourceException('apple-sign-in-${e.code.name}');
    } on fb.FirebaseAuthException catch (e) {
      throw AuthDatasourceException(e.code);
    }
  }

  @override
  Future<void> sendSignInLinkToEmail(String email) => _guard(
    () => _auth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: fb.ActionCodeSettings(
        url: _emailLinkContinueUrl,
        handleCodeInApp: true,
        iOSBundleId: 'com.vikzar.vikzar',
        androidPackageName: 'com.vikzar.vikzar',
        androidInstallApp: true,
        androidMinimumVersion: '1',
      ),
    ),
  );

  @override
  bool isSignInWithEmailLink(String link) => _auth.isSignInWithEmailLink(link);

  @override
  Future<void> signInWithEmailLink({required String email, required String emailLink}) =>
      _guard(() => _auth.signInWithEmailLink(email: email, emailLink: emailLink));

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthDatasourceException(e.code);
    }
  }
}

/// A cryptographically random nonce, hex-encoded — Apple's own sample
/// code pattern for the Sign in with Apple + Firebase combination.
String _generateNonce([int length = 32]) {
  const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
  final random = Random.secure();
  return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
}

final firebaseAuthDatasourceProvider = Provider<AuthDatasource>((ref) {
  return FirebaseAuthDatasource(ref.watch(firebaseAuthProvider));
});
