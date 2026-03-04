import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:premium_force_main/models/user.dart';

/// Local storage service using Hive for persisting user data.
///
/// Stores the [UserModel] as a JSON map so no TypeAdapter / code-gen is needed.
///
/// Usage:
/// ```dart
/// // Initialize once (in main.dart)
/// await UserLocalStorage.init();
///
/// // Save user
/// await UserLocalStorage.saveUser(user);
///
/// // Read user
/// final user = UserLocalStorage.getUser();
///
/// // Check if logged in
/// if (UserLocalStorage.isLoggedIn) { ... }
///
/// // Clear on logout
/// await UserLocalStorage.clearUser();
/// ```
class UserLocalStorage {
  static const String _boxName = 'user_box';
  static const String _userKey = 'current_user';
  static const String _tokenKey = 'auth_token';

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
  // User CRUD
  // ---------------------------------------------------------------------------

  /// Persist the current user.
  static Future<void> saveUser(UserModel user) async {
    await _box.put(_userKey, jsonEncode(user.toJson()));
    debugPrint('💾 User saved: ${user.username}');
  }

  /// Retrieve the current user, or `null` if not logged in.
  static UserModel? getUser() {
    final raw = _box.get(_userKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw as String) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (e) {
      debugPrint('💾 Error reading user: $e');
      return null;
    }
  }

  /// Update specific fields of the stored user.
  static Future<void> updateUser(UserModel Function(UserModel) updater) async {
    final current = getUser();
    if (current == null) return;
    final updated = updater(current);
    await saveUser(updated);
  }

  /// Remove the stored user (logout).
  static Future<void> clearUser() async {
    await _box.delete(_userKey);
    await _box.delete(_tokenKey);
    debugPrint('💾 User data cleared');
  }

  // ---------------------------------------------------------------------------
  // Auth Token
  // ---------------------------------------------------------------------------

  /// Persist the JWT / auth token.
  static Future<void> saveToken(String token) async {
    await _box.put(_tokenKey, token);
  }

  /// Retrieve the stored token, or `null`.
  static String? getToken() {
    return _box.get(_tokenKey) as String?;
  }

  // ---------------------------------------------------------------------------
  // Convenience
  // ---------------------------------------------------------------------------

  /// Whether a user is currently persisted (i.e. logged in).
  static bool get isLoggedIn => _box.containsKey(_userKey);

  /// Quick access to the user's UID without deserializing everything.
  static String? get userId {
    final user = getUser();
    return user?.uid;
  }

  // ---------------------------------------------------------------------------
  // FCM Token
  // ---------------------------------------------------------------------------

  static const String _fcmTokenKey = 'fcm_token';

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
}
