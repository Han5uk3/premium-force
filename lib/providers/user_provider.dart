import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/models/user.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';

enum UserStatus { initial, loading, loaded, failure }

/// Provider that manages the current user's profile data.
///
/// Handles loading from a remote source and profile updates.
/// Uses [ApiService] to communicate with the AWS backend.
class UserProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  UserStatus _status = UserStatus.initial;
  UserStatus get status => _status;

  UserModel? _user;
  UserModel? get user => _user;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Provider methods
  // ---------------------------------------------------------------------------

  /// Load a user profile by [uid].
  Future<void> loadUser(String uid) async {
    _status = UserStatus.loading;
    notifyListeners();

    try {
      final token = UserLocalStorage.getToken();
      final user = await _api.getUserById(id: uid, token: token);

      if (user != null) {
        _user = user;
        _status = UserStatus.loaded;
      } else {
        _status = UserStatus.failure;
        _errorMessage = 'User not found';
      }
      notifyListeners();
    } catch (e) {
      _status = UserStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Update the user profile (locally and remotely).
  Future<void> updateUser(UserModel updatedUser) async {
    _status = UserStatus.loading;
    notifyListeners();

    try {
      final token = UserLocalStorage.getToken();

      final result = await _api.updateUser(
        id: updatedUser.uid,
        username: updatedUser.username,
        email: updatedUser.email,
        countryCode: updatedUser.countryCode,
        phoneNumber: updatedUser.phoneNumber,
        location: updatedUser.location,
        lat: updatedUser.lat,
        long: updatedUser.long,
        role: updatedUser.role,
        token: token,
      );

      if (result['success'] == true) {
        _user = updatedUser;
        _status = UserStatus.loaded;
      } else {
        _status = UserStatus.failure;
        _errorMessage = result['message'] ?? 'Failed to update user';
      }
      notifyListeners();
    } catch (e) {
      _status = UserStatus.failure;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Clear user data (e.g. on logout).
  Future<void> clearUser() async {
    _status = UserStatus.initial;
    _user = null;
    _errorMessage = null;
    notifyListeners();
  }
}
