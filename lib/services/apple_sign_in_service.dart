import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Service that wraps the `sign_in_with_apple` plugin.
///
/// Handles the native Sign in with Apple flow and returns the ID token, email,
/// and profile information so we can send them to our Node.js / MongoDB backend
/// for verification (no Firebase Auth involved).
class AppleSignInService {
  AppleSignInService._();
  static final AppleSignInService instance = AppleSignInService._();

  /// Trigger the native Apple Sign-In flow.
  ///
  /// Returns an [AppleSignInResult] on success or `null` if the user cancelled.
  ///
  /// Apple Sign-In returns:
  /// - user: User identifier (unique per team, cannot change)
  /// - email: User's email (may be private relay email if user hides it)
  /// - givenName/familyName: User's name (only on first sign-in)
  /// - idToken: Opaque token for backend verification
  /// - authorizationCode: Used to refresh tokens on backend
  Future<AppleSignInResult?> signIn() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      debugPrint('🍎 Apple Sign-In │ Success');
      debugPrint('🍎 Apple Sign-In │ User ID: ${credential.userIdentifier}');
      debugPrint('🍎 Apple Sign-In │ Email: ${credential.email}');
      debugPrint(
        '🍎 Apple Sign-In │ Name: ${credential.givenName} ${credential.familyName}',
      );
      debugPrint(
        '🍎 Apple Sign-In │ ID Token present: ${credential.identityToken != null}',
      );

      // Extract email (fallback to empty string if user hides email)
      final email = credential.email ?? '';
      final namePrefix = credential.givenName ?? '';
      final nameSuffix = credential.familyName ?? '';
      final displayName = '$namePrefix $nameSuffix'.trim();

      return AppleSignInResult(
        userId: credential.userIdentifier ?? '',
        email: email,
        displayName: displayName.isEmpty ? null : displayName,
        givenName: credential.givenName,
        familyName: credential.familyName,
        idToken: credential.identityToken,
        authorizationCode: credential.authorizationCode,
        state: credential.state,
      );
    } catch (e) {
      debugPrint('🍎 Apple Sign-In │ Error: $e');
      // Check if user cancelled
      if (e.toString().contains('cancelled') ||
          e.toString().contains('SignInWithAppleAuthorizationException')) {
        debugPrint('🍎 Apple Sign-In │ User cancelled');
        return null;
      }
      rethrow;
    }
  }
}

/// Holds the result of a successful Apple Sign-In.
class AppleSignInResult {
  final String userId; // Unique identifier from Apple
  final String email;
  final String? displayName;
  final String? givenName;
  final String? familyName;
  final String? idToken;
  final String? authorizationCode;
  final String? state;

  const AppleSignInResult({
    required this.userId,
    required this.email,
    this.displayName,
    this.givenName,
    this.familyName,
    this.idToken,
    this.authorizationCode,
    this.state,
  });
}
