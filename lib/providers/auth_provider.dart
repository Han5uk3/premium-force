import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/models/user.dart';

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
      } else {
        _status = AuthStatus.failure;
        _errorMessage = result['message'] as String? ?? 'Signup failed';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Submit SignUp error: $e');
      _status = AuthStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Sign the user out.
  Future<void> logout() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      _cancelResendTimer();
      _user = null;
      _phoneNumber = null;
      _errorMessage = null;
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
