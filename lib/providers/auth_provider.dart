import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/models/user.dart';
import 'package:premium_force_main/services/google_sign_in_service.dart';
import 'package:premium_force_main/services/notification_service.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';

enum AuthStatus {
  initial,
  loading,
  otpSent,
  otpVerified,
  authenticated,
  unauthenticated,
  failure,
}

/// Provider that manages the full authentication lifecycle.
///
/// Uses [ApiService] to communicate with the AWS backend.
class AuthProvider extends ChangeNotifier {
  static const int resendDuration = 60; // seconds

  final ApiService _api = ApiService();
  Timer? _resendTimer;

  AuthStatus _status = AuthStatus.initial;
  AuthStatus get status => _status;

  UserModel? _user;
  UserModel? get user => _user;

  String? _phoneNumber;
  String? get phoneNumber => _phoneNumber;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _resendCountdown = 0;
  int get resendCountdown => _resendCountdown;

  // ---------------------------------------------------------------------------
  // Timer helpers
  // ---------------------------------------------------------------------------

  void _startResendTimer() {
    _cancelResendTimer();
    _resendCountdown = resendDuration;
    notifyListeners();

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _resendCountdown--;
      if (_resendCountdown <= 0) {
        timer.cancel();
      }
      notifyListeners();
    });
  }

  void _cancelResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = null;
  }

  @override
  void dispose() {
    _cancelResendTimer();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Provider methods (former Events)
  // ---------------------------------------------------------------------------

  /// Check whether the user is already logged in (e.g. on app start).
  Future<void> checkAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      // TODO: Check stored token / session.
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      debugPrint('Check Auth error: $e');
      _status = AuthStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Send an OTP to the provided phone number.
  Future<void> requestOtp({
    required String countryCode,
    required String phoneNumber,
  }) async {
    // TODO: BYPASS — SMS service not implemented yet.
    // Uncomment the API call below when ready.
    // final result = await _api.sendOtp(
    //   countryCode: countryCode,
    //   phoneNumber: phoneNumber,
    // );

    _startResendTimer();
    _status = AuthStatus.otpSent;
    _phoneNumber = phoneNumber;
    notifyListeners();
  }

  /// Verify the OTP entered by the user.
  Future<void> verifyOtp({
    required String otp,
    required String countryCode,
    required String phoneNumber,
  }) async {
    // TODO: BYPASS — SMS service not implemented yet.
    // Uncomment the API call below when ready.
    // final result = await _api.verifyOtp(
    //   countryCode: countryCode,
    //   phoneNumber: phoneNumber,
    //   otp: otp,
    // );

    _cancelResendTimer();
    _status = AuthStatus.otpVerified;
    _phoneNumber = phoneNumber;
    _resendCountdown = 0;
    notifyListeners();
  }

  /// Resend the OTP and restart the cooldown timer.
  Future<void> requestOtpResend({
    required String countryCode,
    required String phoneNumber,
  }) async {
    if (_resendCountdown > 0) return;

    // TODO: BYPASS — SMS service not implemented yet.
    // Uncomment the API call below when ready.
    // final result = await _api.sendOtp(
    //   countryCode: countryCode,
    //   phoneNumber: phoneNumber,
    // );

    _startResendTimer();
    _status = AuthStatus.otpSent;
    _phoneNumber = phoneNumber;
    notifyListeners();
  }

  /// Create the user profile after signup form submission.
  Future<void> submitSignUp({
    required String username,
    required String email,
    required String countryCode,
    required String phoneNumber,
    String? location,
    double? lat,
    double? long,
    File? profileImage,
    String? specialId,
  }) async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final result = await _api.createUser(
        username: username,
        email: email,
        countryCode: countryCode,
        phoneNumber: phoneNumber,
        location: location,
        lat: lat,
        long: long,
        profileImage: profileImage,
        specialId: specialId,
      );

      if (result['success'] == true) {
        final userData = result['user'] ?? result['data'] ?? result;
        _user = UserModel.fromJson(userData as Map<String, dynamic>);
        _status = AuthStatus.authenticated;
        notifyListeners();
      } else {
        _status = AuthStatus.failure;
        _errorMessage = result['message'] as String? ?? 'Signup failed';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Submit SignUp error: $e');
      _status = AuthStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Google Sign-In
  // ---------------------------------------------------------------------------

  bool _isGoogleLoading = false;
  bool get isGoogleLoading => _isGoogleLoading;

  /// The Google sign-in result, stored temporarily so the signup page can
  /// pre-fill fields if this is a new user.
  GoogleSignInResult? _googleResult;
  GoogleSignInResult? get googleResult => _googleResult;

  /// Sign in with Google.
  ///
  /// Flow:
  /// 1. Native Google Sign-In (account picker → ID token)
  /// 2. Send ID token to Node.js backend (`POST /auth/google`)
  /// 3. Backend verifies token, creates or retrieves the user from MongoDB.
  /// 4. If user exists → authenticated. If new → otpVerified (go to signup).
  Future<void> signInWithGoogle() async {
    _isGoogleLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await GoogleSignInService.instance.signIn();
      if (result == null) {
        // User cancelled
        _isGoogleLoading = false;
        notifyListeners();
        return;
      }

      _googleResult = result;

      // Debug print the full ID token
      debugPrint('🔐 Google Sign-In │ ID Token:');
      debugPrint('🔐 Google Sign-In │ ${result.idToken}');
      debugPrint('🔐 Google Sign-In │ Email: ${result.email}');
      debugPrint('🔐 Google Sign-In │ Display Name: ${result.displayName}');

      if (result.idToken == null) {
        _status = AuthStatus.failure;
        _errorMessage = 'Failed to get ID token from Google.';
        _isGoogleLoading = false;
        notifyListeners();
        return;
      }

      // Send only idToken to backend
      final response = await _api.googleAuth(idToken: result.idToken!);

      debugPrint('🔐 Google Sign-In │ Backend response: $response');

      if (response['success'] == true) {
        final isNewUser = response['isNewUser'] as bool? ?? false;

        if (isNewUser) {
          // New user — let them go to signup to fill remaining fields
          _status = AuthStatus.otpVerified;
        } else {
          // Existing user — fully authenticated
          final userData = response['user'] ?? response['data'];
          if (userData is Map<String, dynamic>) {
            _user = UserModel.fromJson(userData);
            await UserLocalStorage.saveUser(_user!);
          }

          final token = response['token'] as String?;
          if (token != null) {
            await UserLocalStorage.saveToken(token);
          }

          _status = AuthStatus.authenticated;
        }
      } else {
        _status = AuthStatus.failure;
        _errorMessage =
            response['message'] as String? ?? 'Google sign-in failed';
      }
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      _status = AuthStatus.failure;
      _errorMessage = 'Google sign-in failed. Please try again.';
    }

    _isGoogleLoading = false;
    notifyListeners();
  }

  /// Sign the user out.
  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      // Delete the FCM token so this device stops receiving notifications
      // for the signed-out user.
      await NotificationService.instance.deleteToken();

      // Sign out of Google as well
      await GoogleSignInService.instance.signOut();

      _cancelResendTimer();
      _user = null;
      _phoneNumber = null;
      _errorMessage = null;
      _googleResult = null;
      _resendCountdown = 0;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      debugPrint('Logout error: $e');
      _status = AuthStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
