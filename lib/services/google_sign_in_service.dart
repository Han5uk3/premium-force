import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service that wraps the `google_sign_in` plugin.
///
/// Handles the native Google Sign-In flow and returns the ID token + profile
/// information so we can send them to our Node.js / MongoDB backend for
/// verification (no Firebase Auth involved).
class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService instance = GoogleSignInService._();

  // ── Client IDs from Google Cloud Console ─────────────────────────────────
  //
  // Android Client ID (auto-detected from google-services.json via SHA-1):
  // 265361809546-l7frcki7argtjttarntrgbaqvmj7c5o9.apps.googleusercontent.com
  //
  // Web Client ID (used as serverClientId to request ID tokens):
  static const String _webClientId =
      '265361809546-2db1fc42111enhg4tivodb7v0u52lf45.apps.googleusercontent.com';
  //
  // iOS Client ID:
  static const String _iosClientId =
      '265361809546-8ucet0uausd5aacl6nsatt9b5inbchf8.apps.googleusercontent.com';
  // static const String _androidClientId =
  //     '265361809546-l7frcki7argtjttarntrgbaqvmj7c5o9.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Android: clientId is auto-detected from google-services.json (SHA-1 match)
    //          DO NOT set it manually or you get ApiException: 10
    // iOS:     clientId must be the iOS Client ID
    clientId: Platform.isIOS ? _iosClientId : null,
    // serverClientId = Web Client ID → needed to generate the ID token
    serverClientId: _webClientId,
    signInOption: SignInOption.standard,
  );

  /// Trigger the native Google Sign-In flow.
  ///
  /// Returns a [GoogleSignInResult] on success or `null` if the user cancelled.
  Future<GoogleSignInResult?> signIn() async {
    try {
      // Sign out first to always show the account picker
      await _googleSignIn.signOut();

      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        // User cancelled the sign-in
        debugPrint('🔐 Google Sign-In │ User cancelled');
        return null;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;

      debugPrint('🔐 Google Sign-In │ Success: ${account.email}');
      debugPrint('🔐 Google Sign-In │ ID Token present: ${idToken != null}');

      return GoogleSignInResult(
        idToken: idToken,
        accessToken: auth.accessToken,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        googleId: account.id,
      );
    } catch (e) {
      debugPrint('🔐 Google Sign-In │ Error: $e');
      rethrow;
    }
  }

  /// Attempt to sign in silently in the background.
  ///
  /// Useful for refreshing tokens without showing a UI.
  Future<GoogleSignInResult?> signInSilently() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      if (account == null) return null;

      final GoogleSignInAuthentication auth = await account.authentication;
      return GoogleSignInResult(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        googleId: account.id,
      );
    } catch (e) {
      debugPrint('🔐 Google Sign-In │ Silent Auth Error: $e');
      return null;
    }
  }

  /// Sign out of Google.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}

/// Holds the result of a successful Google Sign-In.
class GoogleSignInResult {
  final String? idToken;
  final String? accessToken;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String googleId;

  const GoogleSignInResult({
    required this.idToken,
    this.accessToken,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.googleId,
  });
}
