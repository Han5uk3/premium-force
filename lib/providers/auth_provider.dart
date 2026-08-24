import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/api/user_api_v2.dart';
import 'package:premium_force_main/models/user.dart';
import 'package:premium_force_main/services/apple_sign_in_service.dart';
import 'package:premium_force_main/services/google_sign_in_service.dart';
import 'package:premium_force_main/services/notification_service.dart';
import 'package:premium_force_main/main.dart'
    show bookingProvider, notificationProvider;
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

  /// The language the app is currently running in, as the API's `locale`.
  ///
  /// Read from Hive rather than from a widget's `BuildContext`: the provider is
  /// used outside the tree (silent refresh on launch), and Hive is what the
  /// language switch persists to anyway.
  String get _currentLocale => UserLocalStorage.getLanguage();

  /// The device's push token, when one has been issued.
  ///
  /// Sent alongside the locale on every auth call so a fresh install is
  /// reachable by push from its first request, without waiting for the separate
  /// token-sync round trip.
  String? get _currentFcmToken => UserLocalStorage.getFcmToken();

  // ---------------------------------------------------------------------------
  // Fetch user from backend
  // ---------------------------------------------------------------------------

  /// Fetch the signed-in customer's full profile from the backend.
  ///
  /// Calls `GET /api/v2/user/me`, which identifies the customer from the bearer
  /// token. [userId] therefore no longer selects *which* profile is read — it
  /// is kept only as the "is anyone signed in" guard it already served, since
  /// every caller passes the stored id or nothing at all.
  ///
  /// Returns the [UserModel] on success, or `null` if the read failed.
  Future<UserModel?> fetchUser({String? userId}) async {
    final id = userId ?? UserLocalStorage.getUserId();
    if (id == null || id.isEmpty) return null;

    final result = (await UserApiV2().getProfile()).data;

    if (result != null) {
      _user = result;
      _status = AuthStatus.authenticated;
      // Persist to local storage to keep cache fresh
      await UserLocalStorage.saveUserData(result.toJson());
      notifyListeners();
    }

    return result;
  }

  /// Update the current user data manually, persist it, and notify listeners.
  ///
  /// Useful after registration or profile updates to ensure immediate UI sync.
  Future<void> updateUser(UserModel user) async {
    _user = user;
    _status = AuthStatus.authenticated;
    await UserLocalStorage.saveUserData(user.toJson());
    notifyListeners();
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
      final isSocialLogin =
          loginProvider == 'google' || loginProvider == 'apple';
      final hasUserId = storedUserId != null && storedUserId.isNotEmpty;
      final hasToken = storedToken != null && storedToken.isNotEmpty;

      if (hasUserId && (hasToken || isSocialLogin)) {
        // --- PREEMPTIVE TOKEN REFRESH ON APP LAUNCH ---
        bool refreshed = false;
        bool sessionExpired = false;
        final storedRefreshToken = UserLocalStorage.getRefreshToken();

        if (storedRefreshToken != null && storedRefreshToken.isNotEmpty) {
          try {
            final result = await _api.refreshAccessToken(
              refreshToken: storedRefreshToken,
            );
            if (result['success'] == true) {
              await _saveAuthTokens(result);
              refreshed = true;
            } else {
              final msg = (result['message'] as String? ?? '').toLowerCase();
              final statusCode = result['statusCode'] as int?;
              if (statusCode == 401 ||
                  statusCode == 403 ||
                  msg.contains('expired') ||
                  msg.contains('invalid')) {
                sessionExpired = true;
              }
            }
          } catch (e) {}
        }

        // If backend refresh was not successful or not possible, and provider is google, try silent sign-in
        if (!refreshed && loginProvider == 'google') {
          try {
            final googleResult = await GoogleSignInService.instance
                .signInSilently();
            if (googleResult != null && googleResult.idToken != null) {
              await UserLocalStorage.saveSocialIdToken(googleResult.idToken!);
              final authResponse = await _api.googleAuth(
                idToken: googleResult.idToken!,
                locale: _currentLocale,
                fcmToken: _currentFcmToken,
              );
              if (authResponse['success'] == true) {
                await _saveAuthTokens(authResponse);
                refreshed = true;
                sessionExpired = false;
              } else {
                final msg = (authResponse['message'] as String? ?? '')
                    .toLowerCase();
                final statusCode = authResponse['statusCode'] as int?;
                if (statusCode == 401 ||
                    statusCode == 403 ||
                    msg.contains('expired') ||
                    msg.contains('invalid')) {
                  sessionExpired = true;
                }
              }
            } else {
              sessionExpired = true;
            }
          } catch (e) {
            sessionExpired = true;
          }
        }

        // If the session is definitively expired, log them out right away
        if (sessionExpired && !refreshed) {
          await UserLocalStorage.clearUser();
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return;
        }
        // ----------------------------------------------
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
              .catchError((e) {});
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
              countryCode: UserLocalStorage.getCountryCode() ?? "",
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
        locale: _currentLocale,
        fcmToken: _currentFcmToken,
      );

      _isOtpLoading = false;
      _cancelResendTimer();

      if (result['success'] == true) {
        // Consolidate token extraction and saving
        await _saveAuthTokens(result);

        // Mark provider as phone
        await UserLocalStorage.saveLoginProvider('phone');

        // --- Handle user data ---
        var userData = result['user'] ?? result['data'];
        if (userData is Map<String, dynamic>) {
          if (userData.containsKey('user') &&
              userData['user'] is Map<String, dynamic>) {
            userData = userData['user'];
          }

          _user = UserModel.fromJson(userData);
          final uid = (userData['_id'] ?? userData['id'] ?? '').toString();
          final phone = (userData['phoneNumber'] ?? phoneNumber).toString();

          await UserLocalStorage.saveUserCredentials(
            userId: uid,
            phoneNumber: phone,
            countryCode: userData['countryCode']?.toString() ?? countryCode,
          );

          await UserLocalStorage.saveUserData(userData);
        }

        _status = AuthStatus.authenticated;
        _phoneNumber = phoneNumber;
        _resendCountdown = 0;

        // Sync FCM token with backend after successful login
        unawaited(NotificationService.instance.syncTokenWithBackend());

        notifyListeners();
      } else {
        // Check if this is a "user not found" scenario — OTP was valid but
        // no account exists yet. Treat as new user → go to signup.
        final message = (result['message'] as String? ?? '').toLowerCase();
        if (message.contains('not found') ||
            message.contains('not registered') ||
            message.contains('register first') ||
            message.contains('not exist')) {
          await _saveAuthTokens(result);

          _status = AuthStatus.otpVerified;
          _phoneNumber = phoneNumber;
          _resendCountdown = 0;
          notifyListeners();
        } else {
          _errorMessage =
              result['message'] as String? ?? 'OTP verification failed';
          _status = AuthStatus.failure;
          notifyListeners();
        }
      }
    } catch (e) {
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
  ///
  /// Returns a result map with `success` (bool) and optional `message` (String).
  /// On success, the [user] is fully populated and [status] is [AuthStatus.authenticated].
  Future<Map<String, dynamic>> submitSignUp({
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
        locale: _currentLocale,
        fcmToken: _currentFcmToken,
      );

      if (result['success'] == true) {
        // Save tokens returned by createUser
        await _saveAuthTokens(result);

        // Save login provider if not already set
        final existingProvider = UserLocalStorage.getLoginProvider();
        if (existingProvider == null || existingProvider.isEmpty) {
          await UserLocalStorage.saveLoginProvider('phone');
        }

        var userData = result['user'] ?? result['data'] ?? result;
        if (userData is Map<String, dynamic>) {
          if (userData.containsKey('user') &&
              userData['user'] is Map<String, dynamic>) {
            userData = userData['user'];
          }

          final uid = (userData['_id'] ?? userData['id'] ?? '').toString();

          // Save credentials immediately so interceptors have the userId
          await UserLocalStorage.saveUserCredentials(
            userId: uid,
            phoneNumber: phoneNumber,
            countryCode: userData['countryCode']?.toString() ?? countryCode,
          );

          // Try to fetch the full user profile from backend
          // (the createUser response may not include all fields like profileImageUrl)
          UserModel? fullUser;
          try {
            // Reads `GET /api/v2/user/me` off the token just saved, so it needs
            // no id — `uid` above is still what the credentials were stored
            // under.
            fullUser = (await UserApiV2().getProfile()).data;
          } catch (e) {}

          if (fullUser != null) {
            _user = fullUser;
            await UserLocalStorage.saveUserData(fullUser.toJson());
          } else {
            // Fallback: build user from the createUser response data
            _user = UserModel.fromJson({
              ...userData,
              'phoneNumber': phoneNumber,
              'countryCode': countryCode,
            });
            await UserLocalStorage.saveUserData(userData);
          }
        }

        _status = AuthStatus.authenticated;

        // Sync FCM token with backend after successful signup
        unawaited(NotificationService.instance.syncTokenWithBackend());

        notifyListeners();
        return {'success': true};
      } else {
        _status = AuthStatus.failure;
        _errorMessage = result['message'] as String? ?? 'Signup failed';
        notifyListeners();
        return {'success': false, 'message': _errorMessage};
      }
    } catch (e) {
      _status = AuthStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
      return {'success': false, 'message': _errorMessage};
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
        await _saveAuthTokens(result);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Extracts tokens from API response and saves them to local storage.
  Future<void> _saveAuthTokens(Map<String, dynamic> result) async {
    final data = result['data'];
    final tokens = result['tokens'] ?? (data is Map ? data['tokens'] : null);

    final accessToken =
        (tokens is Map
                ? (tokens['accessToken'] ?? tokens['token'])
                : (result['accessToken'] ??
                      result['token'] ??
                      (data is Map
                          ? (data['accessToken'] ?? data['token'])
                          : null)))
            as String?;
    final refreshToken =
        (tokens is Map
                ? (tokens['refreshToken'] ?? tokens['refresh_token'])
                : (result['refreshToken'] ??
                      result['refresh_token'] ??
                      (data is Map
                          ? (data['refreshToken'] ?? data['refresh_token'])
                          : null)))
            as String?;

    if (accessToken != null && accessToken.isNotEmpty) {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await UserLocalStorage.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      } else {
        await UserLocalStorage.saveToken(accessToken);
      }
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

      // Step 2: Backend login/check using Google token
      if (result.idToken != null) {
        final authResponse = await _api.googleAuth(
          idToken: result.idToken!,
          locale: _currentLocale,
          fcmToken: _currentFcmToken,
        );

        if (authResponse['success'] == true) {
          final authData = authResponse['data'];
          final bool userExists =
              authData is Map && authData['userExists'] == true;

          if (userExists) {
            // Existing user: Authenticate
            await _saveAuthTokens(authResponse);

            var userData = authData['user'];
            if (userData is Map<String, dynamic>) {
              _user = UserModel.fromJson(userData);
              final uid = (userData['_id'] ?? userData['id'] ?? '').toString();
              final phone = (userData['phoneNumber'] ?? '').toString();

              await UserLocalStorage.saveUserCredentials(
                userId: uid,
                phoneNumber: phone,
                countryCode: userData['countryCode']?.toString() ?? "",
              );

              await UserLocalStorage.saveUserData(userData);

              _status = AuthStatus.authenticated;

              // Sync FCM token after successful Google login
              unawaited(NotificationService.instance.syncTokenWithBackend());
            } else {
              _status = AuthStatus.failure;
              _errorMessage = 'User data missing from authentication response';
            }
          } else {
            // New user: Go to signup
            _status = AuthStatus.otpVerified;
          }
        } else {
          _status = AuthStatus.failure;
          _errorMessage =
              authResponse['message'] ?? 'Backend authentication failed';
        }
      } else {
        _status = AuthStatus.failure;
        _errorMessage = 'Google ID Token is missing';
      }
    } catch (e) {
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

      // Step 2: Backend login/check using Apple token
      if (result.idToken != null) {
        final authResponse = await _api.appleAuth(
          idToken: result.idToken!,
          locale: _currentLocale,
          fcmToken: _currentFcmToken,
        );

        if (authResponse['success'] == true) {
          final authData = authResponse['data'];
          final bool userExists =
              authData is Map && authData['userExists'] == true;

          if (userExists) {
            // Existing user: Authenticate
            await _saveAuthTokens(authResponse);

            var userData = authData['user'];
            if (userData is Map<String, dynamic>) {
              _user = UserModel.fromJson(userData);
              final uid = (userData['_id'] ?? userData['id'] ?? '').toString();
              final phone = (userData['phoneNumber'] ?? '').toString();

              await UserLocalStorage.saveUserCredentials(
                userId: uid,
                phoneNumber: phone,
                countryCode: userData['countryCode']?.toString() ?? "",
              );

              await UserLocalStorage.saveUserData(userData);

              _status = AuthStatus.authenticated;

              // Sync FCM token after successful Apple login
              unawaited(NotificationService.instance.syncTokenWithBackend());
            } else {
              _status = AuthStatus.failure;
              _errorMessage = 'User data missing from authentication response';
            }
          } else {
            // New user: Go to signup
            _status = AuthStatus.otpVerified;
          }
        } else {
          _status = AuthStatus.failure;
          _errorMessage =
              authResponse['message'] ?? 'Backend authentication failed';
        }
      } else {
        _status = AuthStatus.failure;
        _errorMessage = 'Apple ID Token is missing';
      }
    } catch (e) {
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

      // The notification centre and the bookings are per-account, and both now
      // outlive the widget tree; drop what this session holds so the next
      // sign-in starts from an empty inbox and an empty booking list.
      notificationProvider.reset();
      bookingProvider.reset();

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
      _status = AuthStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Delete Account
  // ---------------------------------------------------------------------------

  /// Delete the user account.
  Future<bool> deleteAccount() async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final id = UserLocalStorage.getUserId();
      final token = UserLocalStorage.getToken();

      if (id != null) {
        // Delete user on the backend
        await _api.deleteUser(userid: id, token: token);
      }

      // Cleanup local state (this is what the user meant: delete first, then cleanup)
      await logout();
      return true;
    } catch (e) {
      _status = AuthStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
