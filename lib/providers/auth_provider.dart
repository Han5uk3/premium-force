import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/models/user.dart';
import 'package:premium_force_main/services/apple_sign_in_service.dart';
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
/// Uses [ApiService] to communicate with the backend.
///
/// **Storage strategy**: Only `userId` and `phoneNumber` are stored locally
/// in Hive. Full user data is fetched from the backend via
/// `GET /api/users/:id` when needed (e.g. on app launch, after login).
///
/// OTP Flow:
/// 1. `requestOtp()` → calls `POST /api/otp/send-otp`
/// 2. `verifyOtp()`  → calls `POST /api/otp/verify-otp`
///    - If response contains `user` → existing user → [AuthStatus.authenticated]
///    - If response does NOT contain `user` → new user → [AuthStatus.otpVerified]
/// 3. For new users, `submitSignUp()` creates the profile and navigates to Home.
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

  bool _isOtpLoading = false;
  bool get isOtpLoading => _isOtpLoading;

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
  // Fetch user from backend
  // ---------------------------------------------------------------------------

  /// Fetch the full user profile from the backend using [userId].
  ///
  /// Calls `GET /api/users/:id`. Returns the [UserModel] on success,
  /// or `null` if the user was not found.
  Future<UserModel?> fetchUser({String? userId}) async {
    final id = userId ?? UserLocalStorage.getUserId();
    if (id == null || id.isEmpty) return null;

    final token = UserLocalStorage.getToken();
    final result = await _api.getUserById(id: id, token: token);

    if (result != null) {
      _user = result;
      notifyListeners();
      debugPrint('✅ Fetched user from backend: ${result.username}');
    } else {
      debugPrint('⚠️ Failed to fetch user by id: $id');
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Auth Check (for splash screen)
  // ---------------------------------------------------------------------------

  /// Check whether the user is already logged in (e.g. on app start).
  ///
  /// Reads userId + token from Hive. If they exist, fetches full user
  /// data from the backend and sets [AuthStatus.authenticated].
  Future<void> checkAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final storedUserId = UserLocalStorage.getUserId();
      final storedToken = UserLocalStorage.getToken();
      final loginProvider = UserLocalStorage.getLoginProvider();

      // Check if we have enough credentials to consider the user logged in.
      // For phone login, we need both id and token.
      // For social login, we need at least the id (tokens can be refreshed silently).
      final isSocialLogin = loginProvider == 'google' || loginProvider == 'apple';
      final hasUserId = storedUserId != null && storedUserId.isNotEmpty;
      final hasToken = storedToken != null && storedToken.isNotEmpty;

      if (hasUserId && (hasToken || isSocialLogin)) {
        // First try to load from local storage
        final localData = UserLocalStorage.getUserData();
        if (localData != null) {
          _user = UserModel.fromJson(localData);
          _status = AuthStatus.authenticated;
          notifyListeners();

          // Fetch full user data from backend asynchronously to update local cache
          fetchUser(userId: storedUserId)
              .then((fetchedUser) async {
                if (fetchedUser != null) {
                  _user = fetchedUser;
                  await UserLocalStorage.saveUserData(fetchedUser.toJson());
                  notifyListeners();
                }
              })
              .catchError((e) {
                debugPrint('checkAuth background fetch failed: $e');
              });
        } else {
          // If missing in local storage, get user details from backend using getbyid (via fetchUser)
          final fetchedUser = await fetchUser(userId: storedUserId);
          if (fetchedUser != null) {
            _user = fetchedUser;
            await UserLocalStorage.saveUserData(fetchedUser.toJson());
            _status = AuthStatus.authenticated;
          } else {
            // Fallback user just in case the API fetch fails, to keep user logged in as requested
            _user = UserModel(
              uid: storedUserId,
              username: "User",
              email: "",
              countryCode: "",
              phoneNumber: UserLocalStorage.getPhoneNumber() ?? "",
              createdAt: DateTime.now(),
            );
            _status = AuthStatus.authenticated;
          }
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Check Auth error: $e');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // OTP - Send
  // ---------------------------------------------------------------------------

  /// Send an OTP to the provided phone number.
  ///
  /// Calls `POST /api/otp/send-otp`.
  /// Returns `true` if the OTP was sent successfully, `false` otherwise.
  Future<bool> requestOtp({
    required String countryCode,
    required String phoneNumber,
  }) async {
    _isOtpLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.sendOtp(
        countryCode: countryCode,
        phoneNumber: phoneNumber,
      );

      _isOtpLoading = false;

      if (result['success'] == true) {
        _startResendTimer();
        _status = AuthStatus.otpSent;
        _phoneNumber = phoneNumber;
        notifyListeners();
        return true;
      } else {
        String msg = result['message'] as String? ?? 'Failed to send OTP';
        if (msg.contains("Invalid 'To' Phone Number")) {
          msg = "invalid phone number or country code";
        }
        _errorMessage = msg;
        _status = AuthStatus.failure;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('Request OTP error: $e');
      _isOtpLoading = false;
      _errorMessage = 'Failed to send OTP. Please try again.';
      _status = AuthStatus.failure;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // OTP - Verify
  // ---------------------------------------------------------------------------

  /// Verify the OTP entered by the user.
  ///
  /// Calls `POST /api/otp/verify-otp`.
  ///
  /// Backend response contains:
  /// - `accessToken`, `refreshToken`
  /// - `user` object (only if the phone number belongs to an existing user)
  ///
  /// If `user` exists in the response:
  ///   → Save userId + phoneNumber + tokens to Hive
  ///   → [AuthStatus.authenticated]
  /// If `user` is absent/null:
  ///   → Save tokens to Hive → [AuthStatus.otpVerified] (navigate to signup)
  Future<void> verifyOtp({
    required String otp,
    required String countryCode,
    required String phoneNumber,
  }) async {
    _isOtpLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _api.verifyOtp(
        countryCode: countryCode,
        phoneNumber: phoneNumber,
        otp: otp,
      );

      _isOtpLoading = false;
      _cancelResendTimer();

      if (result['success'] == true) {
        final accessToken = result['accessToken'] as String?;
        final refreshToken = result['refreshToken'] as String?;

        final isRegistered = accessToken != null && accessToken.isNotEmpty;

        if (isRegistered) {
          // --- Save tokens ---
          if (refreshToken != null) {
            await UserLocalStorage.saveTokens(
              accessToken: accessToken,
              refreshToken: refreshToken,
            );
          } else {
            await UserLocalStorage.saveToken(accessToken);
          }

          // Mark provider as phone
          await UserLocalStorage.saveLoginProvider('phone');

          // --- Check if user exists ---
          var userData = result['user'] ?? result['data'];
          if (userData is Map<String, dynamic>) {
            // Handle nested user key
            if (userData.containsKey('user') && userData['user'] is Map<String, dynamic>) {
              userData = userData['user'];
            }

            // Existing user → save only userId + phoneNumber
            _user = UserModel.fromJson(userData);
            final uid = (userData['_id'] ?? userData['id'] ?? '').toString();
            final phone = (userData['phoneNumber'] ?? phoneNumber).toString();

            await UserLocalStorage.saveUserCredentials(
              userId: uid,
              phoneNumber: phone,
            );

            // Persist the full user data locally
            await UserLocalStorage.saveUserData(userData);
          }

          _status = AuthStatus.authenticated;
          _phoneNumber = phoneNumber;
          _resendCountdown = 0;
          debugPrint('✅ Existing user logged in: ${_user?.username ?? ''}');
        } else {
          // New user → navigate to signup
          _status = AuthStatus.otpVerified;
          _phoneNumber = phoneNumber;
          _resendCountdown = 0;
          debugPrint('🆕 New user — redirecting to signup');
        }

        notifyListeners();
      } else {
        // Check if this is a "user not found" scenario — OTP was valid but
        // no account exists yet. Treat as new user → go to signup.
        final message = (result['message'] as String? ?? '').toLowerCase();
        if (message.contains('not found') ||
            message.contains('not registered') ||
            message.contains('register first') ||
            message.contains('not exist')) {
          // Save tokens if the backend returned them even on "failure"
          final accessToken = result['accessToken'] as String?;
          final refreshToken = result['refreshToken'] as String?;
          if (accessToken != null && refreshToken != null) {
            await UserLocalStorage.saveTokens(
              accessToken: accessToken,
              refreshToken: refreshToken,
            );
          } else if (accessToken != null) {
            await UserLocalStorage.saveToken(accessToken);
          }

          _status = AuthStatus.otpVerified;
          _phoneNumber = phoneNumber;
          _resendCountdown = 0;
          debugPrint(
            '🆕 New user (backend: "$message") — redirecting to signup',
          );
          notifyListeners();
        } else {
          _errorMessage =
              result['message'] as String? ?? 'OTP verification failed';
          _status = AuthStatus.failure;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Verify OTP error: $e');
      _isOtpLoading = false;
      _errorMessage = 'Verification failed. Please try again.';
      _status = AuthStatus.failure;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // OTP - Resend
  // ---------------------------------------------------------------------------

  /// Resend the OTP and restart the cooldown timer.
  Future<bool> requestOtpResend({
    required String countryCode,
    required String phoneNumber,
  }) async {
    if (_resendCountdown > 0) return false;

    final result = await _api.sendOtp(
      countryCode: countryCode,
      phoneNumber: phoneNumber,
    );

    if (result['success'] == true) {
      _startResendTimer();
      _status = AuthStatus.otpSent;
      _phoneNumber = phoneNumber;
      notifyListeners();
      return true;
    } else {
      String msg = result['message'] as String? ?? 'Failed to resend OTP';
      if (msg.contains("Invalid 'To' Phone Number")) {
        msg = "invalid phone number or country code";
      }
      _errorMessage = msg;
      _status = AuthStatus.failure;
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Signup
  // ---------------------------------------------------------------------------

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
      final token = UserLocalStorage.getToken();
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
        token: token,
      );

      if (result['success'] == true) {
        // --- Save tokens ---
        final accessToken = result['accessToken'] as String?;
        final refreshToken = result['refreshToken'] as String?;

        if (accessToken != null && refreshToken != null) {
          await UserLocalStorage.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
          );
        } else if (accessToken != null) {
          await UserLocalStorage.saveToken(accessToken);
        }

        var userData = result['user'] ?? result['data'] ?? result;
        if (userData is Map<String, dynamic>) {
          // Handle nested user key
          if (userData.containsKey('user') && userData['user'] is Map<String, dynamic>) {
            userData = userData['user'];
          }

          _user = UserModel.fromJson(userData);
          final uid = (userData['_id'] ?? userData['id'] ?? '').toString();

          await UserLocalStorage.saveUserCredentials(
            userId: uid,
            phoneNumber: phoneNumber,
          );

          // Persist the full user data locally
          await UserLocalStorage.saveUserData(userData);
        }

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
  // Token Refresh
  // ---------------------------------------------------------------------------

  /// Refresh the access token using the stored refresh token.
  Future<bool> refreshToken() async {
    final storedRefreshToken = UserLocalStorage.getRefreshToken();
    if (storedRefreshToken == null) return false;

    try {
      final result = await _api.refreshAccessToken(
        refreshToken: storedRefreshToken,
      );

      if (result['success'] == true) {
        final newAccess = result['accessToken'] as String?;
        final newRefresh = result['refreshToken'] as String?;

        if (newAccess != null && newRefresh != null) {
          await UserLocalStorage.saveTokens(
            accessToken: newAccess,
            refreshToken: newRefresh,
          );
        } else if (newAccess != null) {
          await UserLocalStorage.saveToken(newAccess);
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Token refresh error: $e');
      return false;
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
  /// 1. Native Google Sign-In (account picker → email, displayName, photoUrl, idToken)
  /// 2. Check if email exists in backend using `GET /users/check-email?email=...`
  /// 3. If email exists → fetch user data and authenticate → [AuthStatus.authenticated]
  /// 4. If email doesn't exist → navigate to signup with pre-filled data → [AuthStatus.otpVerified]
  Future<void> signInWithGoogle() async {
    _isGoogleLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Get Google credentials
      final result = await GoogleSignInService.instance.signIn();
      if (result == null) {
        // User cancelled
        _isGoogleLoading = false;
        notifyListeners();
        return;
      }

      _googleResult = result;
      // Store provider and social token early (helps with persistence for new users too)
      await UserLocalStorage.saveLoginProvider('google');
      if (result.idToken != null) {
        await UserLocalStorage.saveSocialIdToken(result.idToken!);
      }

      debugPrint('🔐 Google Sign-In │ Email: ${result.email}');

      // Step 2: Check if email exists in backend
      final emailCheckResponse = await _api.checkEmailExists(
        email: result.email,
      );
      debugPrint(
        '🔐 Google Sign-In │ Email check response: $emailCheckResponse',
      );

      final emailExists =
          emailCheckResponse['success'] == true &&
          (emailCheckResponse['exists'] == true ||
              emailCheckResponse['data'] != null);

      if (emailExists) {
        // Step 3a: Email exists → Fetch full user data
        debugPrint('🔐 Google Sign-In │ Email exists. Fetching user data...');

        // Try to get user data from the response or by email
        var userData = emailCheckResponse['user'] ?? emailCheckResponse['data'];

        if (userData is Map<String, dynamic>) {
          // Handle nested user key
          if (userData.containsKey('user') && userData['user'] is Map<String, dynamic>) {
            userData = userData['user'];
          }

          _user = UserModel.fromJson(userData);
          final uid = (userData['_id'] ?? userData['id'] ?? '').toString();
          final phone = (userData['phoneNumber'] ?? '').toString();

          // Step 3a(ii): Call googleAuth to get session tokens for persistence
          if (result.idToken != null) {
            final authResponse = await _api.googleAuth(idToken: result.idToken!);
            if (authResponse['success'] == true) {
              final accessToken = authResponse['accessToken'] as String?;
              final refreshToken = authResponse['refreshToken'] as String?;
              if (accessToken != null) {
                if (refreshToken != null) {
                  await UserLocalStorage.saveTokens(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                  );
                } else {
                  await UserLocalStorage.saveToken(accessToken);
                }
                debugPrint('✅ Google Sign-In │ Tokens saved for persistence');
              }
            }
          }

          await UserLocalStorage.saveUserCredentials(
            userId: uid,
            phoneNumber: phone,
          );

          // Persist the full user data locally
          await UserLocalStorage.saveUserData(userData);

          // If there's a token in response, save it only if no token was saved
          final token = (userData['token'] ?? emailCheckResponse['token'])?.toString();
          if (token != null && token.isNotEmpty) {
            final existingToken = UserLocalStorage.getToken();
            if (existingToken == null || existingToken.isEmpty) {
              await UserLocalStorage.saveToken(token);
            }
          }

          _status = AuthStatus.authenticated;
          debugPrint(
            '✅ Google Sign-In │ Existing user authenticated: ${_user?.username}',
          );
        } else {
          // Email exists but we couldn't get user data from response
          // This shouldn't happen in normal flow but treating as new user
          _status = AuthStatus.otpVerified;
          debugPrint(
            '⚠️ Google Sign-In │ Email exists but no user data. Going to signup.',
          );
        }
      } else {
        // Step 3b: Email doesn't exist → Navigate to signup
        _status = AuthStatus.otpVerified;
        debugPrint('🆕 Google Sign-In │ New user email. Going to signup.');
      }
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      _status = AuthStatus.failure;
      _errorMessage = 'Google sign-in failed. Please try again.';
    }

    _isGoogleLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Apple Sign-In
  // ---------------------------------------------------------------------------

  bool _isAppleLoading = false;
  bool get isAppleLoading => _isAppleLoading;

  /// The Apple sign-in result, stored temporarily so the signup page can
  /// pre-fill fields if this is a new user.
  AppleSignInResult? _appleResult;
  AppleSignInResult? get appleResult => _appleResult;

  /// Sign in with Apple.
  Future<void> signInWithApple() async {
    _isAppleLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: Get Apple credentials
      final result = await AppleSignInService.instance.signIn();
      if (result == null) {
        // User cancelled
        _isAppleLoading = false;
        notifyListeners();
        return;
      }

      _appleResult = result;
      // Store provider and social token early
      await UserLocalStorage.saveLoginProvider('apple');
      if (result.idToken != null) {
        await UserLocalStorage.saveSocialIdToken(result.idToken!);
      }

      debugPrint('🍎 Apple Sign-In │ User ID: ${result.userId}');

      // Step 2: Check if email exists in backend
      final emailCheckResponse = await _api.checkEmailExists(
        email: result.email,
      );
      debugPrint(
        '🍎 Apple Sign-In │ Email check response: $emailCheckResponse',
      );

      final emailExists =
          emailCheckResponse['success'] == true &&
          (emailCheckResponse['exists'] == true ||
              emailCheckResponse['data'] != null);

      if (emailExists) {
        // Step 3a: Email exists → Fetch full user data
        debugPrint('🍎 Apple Sign-In │ Email exists. Fetching user data...');

        // Try to get user data from the response or by email
        var userData = emailCheckResponse['user'] ?? emailCheckResponse['data'];

        if (userData is Map<String, dynamic>) {
          // Handle nested user key
          if (userData.containsKey('user') && userData['user'] is Map<String, dynamic>) {
            userData = userData['user'];
          }

          _user = UserModel.fromJson(userData);
          final uid = (userData['_id'] ?? userData['id'] ?? '').toString();
          final phone = (userData['phoneNumber'] ?? '').toString();

          // Step 3a(ii): Call appleAuth to get session tokens for persistence
          if (result.idToken != null) {
            final authResponse = await _api.appleAuth(idToken: result.idToken!);
            if (authResponse['success'] == true) {
              final accessToken = authResponse['accessToken'] as String?;
              final refreshToken = authResponse['refreshToken'] as String?;
              if (accessToken != null) {
                if (refreshToken != null) {
                  await UserLocalStorage.saveTokens(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                  );
                } else {
                  await UserLocalStorage.saveToken(accessToken);
                }
                debugPrint('🍎 Apple Sign-In │ Tokens saved for persistence');
              }
            }
          }

          await UserLocalStorage.saveUserCredentials(
            userId: uid,
            phoneNumber: phone,
          );

          // Persist the full user data locally
          await UserLocalStorage.saveUserData(userData);

          // If there's a token in response, save it only if no token was saved
          final token = (userData['token'] ?? emailCheckResponse['token'])?.toString();
          if (token != null && token.isNotEmpty) {
            final existingToken = UserLocalStorage.getToken();
            if (existingToken == null || existingToken.isEmpty) {
              await UserLocalStorage.saveToken(token);
            }
          }

          _status = AuthStatus.authenticated;
          debugPrint(
            '✅ Apple Sign-In │ Existing user authenticated: ${_user?.username}',
          );
        } else {
          // Email exists but we couldn't get user data from response
          _status = AuthStatus.otpVerified;
          debugPrint(
            '⚠️ Apple Sign-In │ Email exists but no user data. Going to signup.',
          );
        }
      } else {
        // Step 3b: Email doesn't exist → Navigate to signup
        _status = AuthStatus.otpVerified;
        debugPrint('🆕 Apple Sign-In │ New user email. Going to signup.');
      }
    } catch (e) {
      debugPrint('Apple Sign-In error: $e');
      _status = AuthStatus.failure;
      _errorMessage = 'Apple sign-in failed. Please try again.';
    }

    _isAppleLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------

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

      // Clear local storage
      await UserLocalStorage.clearUser();

      _cancelResendTimer();
      _user = null;
      _phoneNumber = null;
      _errorMessage = null;
      _googleResult = null;
      _appleResult = null;
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

  // ---------------------------------------------------------------------------
  // Delete Account
  // ---------------------------------------------------------------------------

  /// Delete the user account.
  Future<void> deleteAccount() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final id = UserLocalStorage.getUserId();
      final token = UserLocalStorage.getToken();

      if (id != null) {
        // Delete user on the backend
        await _api.deleteUser(id: id, token: token);
      }

      // Delete the FCM token so this device stops receiving notifications
      await NotificationService.instance.deleteToken();

      // Sign out of Google as well
      await GoogleSignInService.instance.signOut();

      // Clear local storage
      await UserLocalStorage.clearUser();

      _cancelResendTimer();
      _user = null;
      _phoneNumber = null;
      _errorMessage = null;
      _googleResult = null;
      _resendCountdown = 0;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      debugPrint('Delete Account error: $e');
      _status = AuthStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
