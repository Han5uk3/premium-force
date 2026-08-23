import 'package:premium_force_main/api/api_result.dart';
import 'package:premium_force_main/api/v2_client.dart';
import 'package:premium_force_main/models/user.dart';
import 'package:premium_force_main/utils/json_utils.dart';

/// The account settings the app keeps in step with the backend.
///
/// Returned by `PATCH /user/settings` so a caller can confirm what the server
/// now holds instead of assuming its request was applied verbatim.
class UserSettingsV2 {
  const UserSettingsV2({this.customerId, this.locale, this.fcmToken});

  final String? customerId;

  /// `"en"` or `"ar"` — the language every push and email is rendered in.
  final String? locale;

  final String? fcmToken;

  factory UserSettingsV2.fromJson(Map<String, dynamic> json) {
    return UserSettingsV2(
      customerId: pickId(json, const ['customerId', '_id', 'id']),
      locale: pickString(json, const ['locale', 'language']),
      fcmToken: pickString(json, const ['fcmToken']),
    );
  }
}

/// Client for the customer's own account (`/api/v2/user/…`).
///
/// The backend renders push notifications and emails server-side, so it needs to
/// know the language the customer reads. Every in-app language switch is mirrored
/// here; the same call carries the current FCM token, which keeps device
/// registration fresh without a second round trip.
///
/// Usage:
/// ```dart
/// await UserApiV2().updateSettings(locale: 'ar');
/// ```
class UserApiV2 extends V2ApiClient {
  static final UserApiV2 _instance = UserApiV2._internal();
  factory UserApiV2() => _instance;

  UserApiV2._internal();

  /// Read the signed-in customer's profile.
  ///
  /// Calls `GET /api/v2/user/me`, which identifies the customer from the
  /// bearer token rather than from an id in the path — so it needs no user id
  /// and always answers for whoever the stored token belongs to. The token is
  /// attached by [V2ApiClient]'s interceptor, which also refreshes and retries
  /// on a 401.
  ///
  /// Returns the shared [UserModel] rather than a v2-specific type: this is
  /// the same customer record the rest of the app already holds, and the model
  /// tolerates both shapes the backend returns it in.
  Future<ApiResult<UserModel>> getProfile() {
    return request(
      () => dio.get('user/me'),
      parse: (payload) {
        final body = asMap(payload);
        // The document arrives either bare or wrapped, depending on the route.
        final nested = pickMap(body, const ['user', 'customer', 'profile']);
        return UserModel.fromJson(nested.isEmpty ? body : nested);
      },
    );
  }

  /// Update the customer's preferred language and/or device push token.
  ///
  /// Both fields are optional; whichever is supplied is sent. Calling with
  /// neither is a no-op that reports success without touching the network.
  Future<ApiResult<UserSettingsV2>> updateSettings({
    String? locale,
    String? fcmToken,
  }) {
    final body = <String, dynamic>{
      if (locale != null && locale.trim().isNotEmpty) 'locale': locale.trim(),
      if (fcmToken != null && fcmToken.trim().isNotEmpty)
        'fcmToken': fcmToken.trim(),
    };

    if (body.isEmpty) {
      return Future.value(const ApiResult<UserSettingsV2>.ok(UserSettingsV2()));
    }

    return request(
      () => dio.patch('user/settings', data: body),
      parse: (payload) => UserSettingsV2.fromJson(asMap(payload)),
    );
  }
}
