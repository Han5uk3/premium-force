import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Local storage service using Hive for persisting minimal user credentials.
///
/// Only stores **userId**, **phoneNumber**, and auth tokens locally.
/// Full user data is fetched from the backend via `GET /api/users/:id`
/// whenever needed.
///
/// Usage:
/// ```dart
/// // Initialize once (in main.dart)
/// await UserLocalStorage.init();
///
/// // Save credentials after login
/// await UserLocalStorage.saveUserCredentials(userId: '...', phoneNumber: '...');
///
/// // Read stored id / phone
/// final uid = UserLocalStorage.getUserId();
///
/// // Check if logged in
/// if (UserLocalStorage.isLoggedIn) { ... }
///
/// // Clear on logout
/// await UserLocalStorage.clearUser();
/// ```
class UserLocalStorage {
  static const String _boxName = 'user_box';

  // Keys
  static const String _userIdKey = 'user_id';
  static const String _phoneNumberKey = 'phone_number';
  static const String _countryCodeKey = 'country_code';
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _fcmTokenKey = 'fcm_token';
  static const String _userDataKey = 'user_data';
  static const String _notificationStatusKey = 'notification_status';
  static const String _loginProviderKey = 'login_provider';
  static const String _socialIdTokenKey = 'social_id_token';
  static const String _fleetCarsKey = 'fleet_cars';

  static late Box<dynamic> _box;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Call once before runApp.
  static Future<void> init() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
    debugPrint('💾 UserLocalStorage initialized');
  }

  // ---------------------------------------------------------------------------
  // User Credentials (minimal — only id + phone)
  // ---------------------------------------------------------------------------

  /// Save only the userId, countryCode and phoneNumber after a successful login/signup.
  static Future<void> saveUserCredentials({
    required String userId,
    required String phoneNumber,
    required String countryCode,
  }) async {
    await _box.put(_userIdKey, userId);
    await _box.put(_phoneNumberKey, phoneNumber);
    await _box.put(_countryCodeKey, countryCode);
    debugPrint(
      '💾 User credentials saved: id=$userId, countryCode=$countryCode, phone=$phoneNumber',
    );
  }

  /// Retrieve the stored userId, or `null` if not logged in.
  static String? getUserId() {
    return _box.get(_userIdKey) as String?;
  }

  /// Retrieve the stored phone number, or `null`.
  static String? getPhoneNumber() {
    return _box.get(_phoneNumberKey) as String?;
  }

  /// Retrieve the stored country code, or `null`.
  static String? getCountryCode() {
    return _box.get(_countryCodeKey) as String?;
  }

  /// Remove all stored user data (logout).
  static Future<void> clearUser() async {
    await _box.delete(_userIdKey);
    await _box.delete(_phoneNumberKey);
    await _box.delete(_countryCodeKey);
    await _box.delete(_tokenKey);
    await _box.delete(_refreshTokenKey);
    await _box.delete(_userDataKey);
    await _box.delete(_loginProviderKey);
    await _box.delete(_socialIdTokenKey);
    debugPrint('💾 User data cleared');
  }

  // ---------------------------------------------------------------------------
  // Full User Data (JSON)
  // ---------------------------------------------------------------------------

  /// Persist the full user profile as a JSON string.
  ///
  /// Call this after a successful login (verifyOtp with user data) or after
  /// registration (createUser returns the new user object).
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final jsonString = jsonEncode(userData);
    await _box.put(_userDataKey, jsonString);
    debugPrint('💾 Full user data saved locally');
  }

  /// Retrieve the stored user data as a JSON map, or `null` if not stored.
  static Map<String, dynamic>? getUserData() {
    final raw = _box.get(_userDataKey) as String?;
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ Failed to decode stored user data: $e');
      return null;
    }
  }

  /// Remove only the cached user data (keeps credentials & tokens intact).
  static Future<void> clearUserData() async {
    await _box.delete(_userDataKey);
  }

  // ---------------------------------------------------------------------------
  // Auth Tokens (access + refresh)
  // ---------------------------------------------------------------------------

  /// Persist the access token (JWT).
  static Future<void> saveToken(String token) async {
    await _box.put(_tokenKey, token);
  }

  /// Retrieve the stored access token, or `null`.
  static String? getToken() {
    return _box.get(_tokenKey) as String?;
  }

  /// Persist the refresh token.
  static Future<void> saveRefreshToken(String token) async {
    await _box.put(_refreshTokenKey, token);
  }

  /// Retrieve the stored refresh token, or `null`.
  static String? getRefreshToken() {
    return _box.get(_refreshTokenKey) as String?;
  }

  /// Save both tokens at once (convenience method after login/verify).
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _box.put(_tokenKey, accessToken);
    await _box.put(_refreshTokenKey, refreshToken);
    debugPrint('💾 Tokens saved');
  }

  // ---------------------------------------------------------------------------
  // Convenience
  // ---------------------------------------------------------------------------

  /// Whether a user is currently logged in (userId is stored).
  static bool get isLoggedIn => _box.containsKey(_userIdKey);

  /// Alias for [getUserId] — for backward compatibility.
  static String? get userId => getUserId();

  // ---------------------------------------------------------------------------
  // FCM Token
  // ---------------------------------------------------------------------------

  /// Persist the FCM registration token.
  static Future<void> saveFcmToken(String token) async {
    await _box.put(_fcmTokenKey, token);
    debugPrint('💾 FCM token saved');
  }

  /// Retrieve the stored FCM token, or `null` if never saved.
  static String? getFcmToken() {
    return _box.get(_fcmTokenKey) as String?;
  }

  /// Clear the stored FCM token (e.g. on logout / token rotation).
  static Future<void> clearFcmToken() async {
    await _box.delete(_fcmTokenKey);
  }

  // ---------------------------------------------------------------------------
  // User Preferences
  // ---------------------------------------------------------------------------

  /// Persist the notification active status.
  static Future<void> saveNotificationStatus(bool status) async {
    await _box.put(_notificationStatusKey, status);
  }

  /// Retrieve the notification status, defaults to true.
  static bool getNotificationStatus() {
    return _box.get(_notificationStatusKey, defaultValue: true) as bool;
  }

  // ---------------------------------------------------------------------------
  // Provider Specific (Local Storage Focused Auth)
  // ---------------------------------------------------------------------------

  /// Save whether the user logged in via phone, google, or apple.
  static Future<void> saveLoginProvider(String provider) async {
    await _box.put(_loginProviderKey, provider);
  }

  /// Get the current login provider ('phone', 'google', 'apple').
  static String? getLoginProvider() {
    return _box.get(_loginProviderKey) as String?;
  }

  /// Save the native social ID token (IdToken) from Google/Apple.
  static Future<void> saveSocialIdToken(String token) async {
    await _box.put(_socialIdTokenKey, token);
  }

  /// Get the stored native social ID token.
  static String? getSocialIdToken() {
    return _box.get(_socialIdTokenKey) as String?;
  }

  // ---------------------------------------------------------------------------
  // Fleet Data (JSON Caching)
  // ---------------------------------------------------------------------------

  /// Persist the fleet list as a JSON string.
  static Future<void> saveFleetCars(List<Map<String, dynamic>> fleetCars) async {
    final jsonString = jsonEncode(fleetCars);
    await _box.put(_fleetCarsKey, jsonString);
    debugPrint('💾 Fleet cars data cached locally');
  }

  /// Retrieve the cached fleet list from Hive.
  static List<Map<String, dynamic>>? getFleetCars() {
    final raw = _box.get(_fleetCarsKey) as String?;
    if (raw == null) return null;
    try {
      final List<dynamic> decoded = jsonDecode(raw);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('⚠️ Failed to decode stored fleet data: $e');
      return null;
    }
  }

  /// Clear the cached fleet data.
  static Future<void> clearFleetCars() async {
    await _box.delete(_fleetCarsKey);
  }
}
