import 'package:flutter/foundation.dart';
import 'package:premium_force_main/models/user.dart';

enum UserStatus { initial, loading, loaded, failure }

/// Provider that manages the current user's profile data.
///
/// Handles loading from a remote source and profile updates.
/// Replace the `// TODO` sections with real AWS backend logic.
class UserProvider extends ChangeNotifier {
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
      // TODO: Fetch user data from AWS backend.
      // ... await apiService.fetchUser(uid);
      // _user = user;
      // _status = UserStatus.loaded;

      // Placeholder – emits failure until AWS API is wired.
      _status = UserStatus.failure;
      _errorMessage = 'AWS API not yet connected';
      notifyListeners();
    } catch (e) {
      debugPrint('Load User error: $e');
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
      // TODO: Update data via AWS backend.
      // ... await apiService.updateUser(updatedUser.toJson());

      _user = updatedUser;
      _status = UserStatus.loaded;
      notifyListeners();
    } catch (e) {
      debugPrint('Update User error: $e');
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
