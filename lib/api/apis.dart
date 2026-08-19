import 'dart:developer' as dev;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/api_logger.dart';
import 'package:premium_force_main/models/user.dart';
import 'package:premium_force_main/services/google_sign_in_service.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';

/// Centralised API service for the Premium Force app.
///
/// Uses [Dio] with a built-in logging interceptor for clear debugging.
///
/// Usage:
/// ```dart
/// final api = ApiService();
/// final result = await api.createUser(...);
/// ```
class ApiService {
  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  static const String _baseUrl = 'https://api.premiumforcegroup.com/api/';

  // ---------------------------------------------------------------------------

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio _dio;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Accept': 'application/json'},
      ),
    );

    // ── Token Refresh Interceptor ──────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final token = UserLocalStorage.getToken();
          final currentUserId = UserLocalStorage.getUserId();
          if (currentUserId != null) debugPrint('👤 User ID │ $currentUserId');
          final path = options.path;

          // Don't attach token for auth endpoints
          final isAuthEndpoint =
              path.contains('otp/') ||
              path.contains('auth/') ||
              path.contains('check-email');

          if (token != null &&
              options.headers['Authorization'] == null &&
              !isAuthEndpoint) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          // Check if error is 401 Unauthorized
          if (e.response?.statusCode == 401) {
            final provider = UserLocalStorage.getLoginProvider();
            debugPrint('🔄 API │ Unauthorized (401). Provider: $provider');

            final refreshToken = UserLocalStorage.getRefreshToken();
            String? newAccess;
            String? newRefresh;

            // 1. Attempt Backend Refresh
            if (refreshToken != null && refreshToken.isNotEmpty) {
              debugPrint('🔄 API │ Attempting backend token refresh...');
              try {
                // Use a separate Dio instance to avoid interceptor loop
                final refreshDio = Dio(
                  BaseOptions(
                    baseUrl: _baseUrl,
                    headers: {
                      'Accept': 'application/json',
                      'Content-Type': 'application/json',
                    },
                  ),
                );
                final refreshResponse = await refreshDio.post(
                  'otp/refresh-token',
                  data: {'refreshToken': refreshToken},
                );

                if (refreshResponse.statusCode == 200 &&
                    refreshResponse.data != null) {
                  final respData = refreshResponse.data;
                  final tokens =
                      respData['tokens'] ??
                      (respData['data'] is Map
                          ? respData['data']['tokens']
                          : null);

                  newAccess =
                      (tokens is Map
                              ? (tokens['accessToken'] ?? tokens['token'])
                              : (respData['accessToken'] ??
                                    respData['token'] ??
                                    (respData['data'] is Map
                                        ? (respData['data']['accessToken'] ??
                                              respData['data']['token'])
                                        : null)))
                          as String?;
                  newRefresh =
                      (tokens is Map
                              ? (tokens['refreshToken'] ??
                                    tokens['refresh_token'])
                              : (respData['refreshToken'] ??
                                    respData['refresh_token'] ??
                                    (respData['data'] is Map
                                        ? (respData['data']['refreshToken'] ??
                                              respData['data']['refresh_token'])
                                        : null)))
                          as String?;
                }
              } catch (reErr) {
                debugPrint('❌ API │ Refresh failed: $reErr');
              }
            }

            // 2. Fallback for Social Login (if backend refresh failed)
            if (newAccess == null &&
                (provider == 'google' || provider == 'apple') &&
                !e.requestOptions.path.contains('auth/')) {
              final socialIdToken = UserLocalStorage.getSocialIdToken();
              if (socialIdToken != null && socialIdToken.isNotEmpty) {
                debugPrint('🔄 API │ Attempting social re-auth ($provider)...');
                try {
                  final authResponse = provider == 'google'
                      ? await googleAuth(idToken: socialIdToken)
                      : await appleAuth(idToken: socialIdToken);

                  if (authResponse['success'] == true) {
                    final tokens = authResponse['tokens'];
                    newAccess =
                        (tokens is Map
                                ? (tokens['accessToken'] ?? tokens['token'])
                                : (authResponse['accessToken'] ??
                                      authResponse['token']))
                            as String?;
                    newRefresh =
                        (tokens is Map
                                ? (tokens['refreshToken'] ??
                                      tokens['refresh_token'])
                                : (authResponse['refreshToken'] ??
                                      authResponse['refresh_token']))
                            as String?;
                  } else if (provider == 'google') {
                    // Try silent sign-in if native token expired
                    debugPrint(
                      '🔄 API │ Social re-auth failed. Trying silent Google sign-in...',
                    );
                    final googleResult = await GoogleSignInService.instance
                        .signInSilently();
                    if (googleResult != null && googleResult.idToken != null) {
                      await UserLocalStorage.saveSocialIdToken(
                        googleResult.idToken!,
                      );
                      final secondAuthRes = await googleAuth(
                        idToken: googleResult.idToken!,
                      );
                      if (secondAuthRes['success'] == true) {
                        final tokens = secondAuthRes['tokens'];
                        newAccess =
                            (tokens is Map
                                    ? (tokens['accessToken'] ?? tokens['token'])
                                    : (secondAuthRes['accessToken'] ??
                                          secondAuthRes['token']))
                                as String?;
                        newRefresh =
                            (tokens is Map
                                    ? (tokens['refreshToken'] ??
                                          tokens['refresh_token'])
                                    : (secondAuthRes['refreshToken'] ??
                                          secondAuthRes['refresh_token']))
                                as String?;
                      }
                    }
                  }
                } catch (reErr) {
                  debugPrint('❌ API │ Social re-auth failed: $reErr');
                }
              }
            }

            // 3. If we got new tokens, save them and retry original request
            if (newAccess != null && newAccess.isNotEmpty) {
              if (newRefresh != null && newRefresh.isNotEmpty) {
                await UserLocalStorage.saveTokens(
                  accessToken: newAccess,
                  refreshToken: newRefresh,
                );
              } else {
                await UserLocalStorage.saveToken(newAccess);
              }
              debugPrint('✅ API │ Tokens refreshed successfully.');

              debugPrint('🔄 API │ Retrying original request...');
              e.requestOptions.headers['Authorization'] = 'Bearer $newAccess';

              try {
                final response = await _dio.fetch(e.requestOptions);
                return handler.resolve(response);
              } catch (retryErr) {
                return handler.next(retryErr is DioException ? retryErr : e);
              }
            }
          }
          return handler.next(e);
        },
      ),
    );

    // ── Logging interceptor (debug mode only) ──────────────
    // Added last so onRequest runs after the interceptor above has attached the
    // Authorization header — the log then shows what actually went on the wire.
    // Responses run interceptors in reverse, so this also reports the outcome
    // after any token refresh and retry, rather than the 401 that triggered it.
    if (kDebugMode) {
      _dio.interceptors.add(BookingApiLogger(label: 'api'));
    }
  }

  /// The preferred-language and push-token fields the auth endpoints accept.
  ///
  /// Registration, OTP verification and both social logins all take the same
  /// optional pair, and all of them treat a missing value as "leave unchanged" —
  /// so blank entries are dropped rather than sent empty.
  static Map<String, String> _localePayload(String? locale, String? fcmToken) {
    final language = locale?.trim();
    final token = fcmToken?.trim();
    return {
      if (language != null && language.isNotEmpty) 'locale': language,
      if (token != null && token.isNotEmpty) 'fcmToken': token,
    };
  }

  /// Attach a Bearer token for authenticated requests.
  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  // ---------------------------------------------------------------------------
  // Auth - OTP
  // ---------------------------------------------------------------------------

  /// Request an OTP for the given [phoneNumber].
  Future<Map<String, dynamic>> sendOtp({
    required String countryCode,
    required String phoneNumber,
    String purpose = 'login',
  }) async {
    try {
      final response = await _dio.post(
        'otp/send-otp',
        data: {
          'countryCode': countryCode,
          'phoneNumber': phoneNumber,
          'purpose': purpose,
        },
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Verify the [otp] for the given [phoneNumber].
  ///
  /// On success the backend returns:
  /// - `accessToken` / `refreshToken`
  /// - `user` (if the user already exists in DB)
  ///
  /// [locale] and [fcmToken] ride along so the backend can start addressing this
  /// user in their language, and on this device, from the moment they log in.
  Future<Map<String, dynamic>> verifyOtp({
    required String countryCode,
    required String phoneNumber,
    required String otp,
    String purpose = 'login',
    String? locale,
    String? fcmToken,
  }) async {
    try {
      final response = await _dio.post(
        'otp/verify-otp',
        data: {
          'countryCode': countryCode,
          'phoneNumber': phoneNumber,
          'otp': otp,
          'purpose': purpose,
          ..._localePayload(locale, fcmToken),
        },
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Refresh the access token using a valid [refreshToken].
  Future<Map<String, dynamic>> refreshAccessToken({
    required String refreshToken,
  }) async {
    try {
      final response = await _dio.post(
        'otp/refresh-token',
        data: {'refreshToken': refreshToken},
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Auth - Google Sign-In & Apple Sign-In
  // ---------------------------------------------------------------------------

  /// Authenticate with Google.
  ///
  /// Sends the Google [idToken] along with platform type to the backend.
  /// The endpoint lives at `/auth/google` (outside the `/api` prefix).
  Future<Map<String, dynamic>> googleAuth({
    required String idToken,
    String? locale,
    String? fcmToken,
  }) async {
    try {
      final data = {'idToken': idToken, ..._localePayload(locale, fcmToken)};

      dev.log('🔐 Google Auth │ Sending data: $data');

      final response = await _dio.post('auth/google', data: data);

      debugPrint('🔐 Google Auth │ Response: ${response.data}');

      return _success(response);
    } catch (e) {
      debugPrint('🔐 Google Auth │ Error: $e');
      return _handleError(e);
    }
  }

  /// Authenticate with Apple.
  ///
  /// Sends the Apple [idToken] along with platform type to the backend.
  /// The endpoint lives at `/auth/apple` (outside the `/api` prefix).
  Future<Map<String, dynamic>> appleAuth({
    required String idToken,
    String? locale,
    String? fcmToken,
  }) async {
    try {
      final data = {'idToken': idToken, ..._localePayload(locale, fcmToken)};

      dev.log('🍎 Apple Auth │ Sending data: $data');

      final response = await _dio.post('auth/apple', data: data);

      debugPrint('🍎 Apple Auth │ Response: ${response.data}');

      return _success(response);
    } catch (e) {
      debugPrint('🍎 Apple Auth │ Error: $e');
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // User Profile
  // ---------------------------------------------------------------------------

  /// Create a new user profile.
  ///
  /// Uses **multipart form-data** to match the backend's expected format.
  Future<Map<String, dynamic>> createUser({
    required String username,
    required String email,
    required String countryCode,
    required String phoneNumber,
    String? location,
    double? lat,
    double? long,
    String? specialId,
    String role = 'customer',
    File? profileImage,
    String? token,
    String? locale,
    String? fcmToken,
  }) async {
    try {
      final formData = FormData.fromMap({
        'username': username,
        'email': email,
        'countryCode': countryCode,
        'phoneNumber': phoneNumber,
        'role': role,
        ..._localePayload(locale, fcmToken),
        if (location != null) 'location': location,
        if (lat != null) 'lat': lat.toString(),
        if (long != null) 'long': long.toString(),
        if (specialId != null && specialId.isNotEmpty) 'specialId': specialId,
        if (profileImage != null)
          'profileImage': await MultipartFile.fromFile(
            profileImage.path,
            filename:
                '${username.replaceAll(' ', '_').toLowerCase()}_profile.${profileImage.path.split('.').last}',
          ),
      });

      final response = await _dio.post(
        'users',
        data: formData,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401 && token == null) {
        final newToken = UserLocalStorage.getToken();
        if (newToken != null) {
          debugPrint('🔄 API [Retry] │ Re-executing createUser...');
          return await createUser(
            username: username,
            email: email,
            countryCode: countryCode,
            phoneNumber: phoneNumber,
            location: location,
            lat: lat,
            long: long,
            specialId: specialId,
            role: role,
            profileImage: profileImage,
            token: newToken,
            locale: locale,
            fcmToken: fcmToken,
          );
        }
      }
      return _handleError(e);
    }
  }

  /// Fetch a single user by [id] (MongoDB ObjectId).
  ///
  /// Returns a [UserModel] on success, or `null` if not found.
  Future<UserModel?> getUserById({required String id, String? token}) async {
    try {
      final response = await _dio.get(
        'users/$id',
        options: token != null ? _authOptions(token) : null,
      );
      final data = _success(response);
      if (data['success'] == true) {
        final userData = data['user'] ?? data['data'] ?? data;
        if (userData is Map<String, dynamic> &&
            userData.containsKey('username')) {
          return UserModel.fromJson(userData);
        }
      }
      return null;
    } catch (e) {
      debugPrint('getUserById error: $e');
      return null;
    }
  }

  /// Update an existing user profile.
  ///
  /// Uses **multipart form-data** to support optional image updates.
  Future<Map<String, dynamic>> updateUser({
    required String id,
    String? username,
    String? email,
    String? countryCode,
    String? phoneNumber,
    String? location,
    double? lat,
    double? long,
    String? specialId,
    String? role,
    File? profileImage,
    String? token,
  }) async {
    try {
      final fields = <String, dynamic>{};
      if (username != null) fields['username'] = username;
      if (email != null) fields['email'] = email;
      if (countryCode != null) fields['countryCode'] = countryCode;
      if (phoneNumber != null) fields['phoneNumber'] = phoneNumber;
      if (location != null) fields['location'] = location;
      if (lat != null) fields['lat'] = lat.toString();
      if (long != null) fields['long'] = long.toString();
      if (specialId != null) fields['specialId'] = specialId;
      if (role != null) fields['role'] = role;
      if (profileImage != null) {
        final name = (username ?? 'user').replaceAll(' ', '_').toLowerCase();
        fields['profileImage'] = await MultipartFile.fromFile(
          profileImage.path,
          filename: '${name}_profile.${profileImage.path.split('.').last}',
        );
      }

      final response = await _dio.put(
        'users/$id',
        data: FormData.fromMap(fields),
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401 && token == null) {
        final newToken = UserLocalStorage.getToken();
        if (newToken != null) {
          debugPrint('🔄 API [Retry] │ Re-executing updateUser...');
          return await updateUser(
            id: id,
            username: username,
            email: email,
            countryCode: countryCode,
            phoneNumber: phoneNumber,
            location: location,
            lat: lat,
            long: long,
            specialId: specialId,
            role: role,
            profileImage: profileImage,
            token: newToken,
          );
        }
      }
      return _handleError(e);
    }
  }

  /// Delete a user by [id].
  Future<Map<String, dynamic>> deleteUser({
    required String userid,
    String? token,
  }) async {
    try {
      final response = await _dio.delete(
        'users/$userid',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Update a user's FCM registration token.
  ///
  /// Calls `POST /api/users/:id/fcm-token`
  Future<Map<String, dynamic>> updateFcmToken({
    required String userid,
    required String fcmToken,
    String? token,
  }) async {
    try {
      final response = await _dio.post(
        'users/$userid/fcm-token',
        data: {'fcmToken': fcmToken},
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Car Data (Categories, Brands, Cars)
  // ---------------------------------------------------------------------------

  /// Fetch a specific brand by ID from the backend.
  ///
  /// Calls `GET /api/brands/:id`
  /// Returns the brand details including logo/image.
  Future<Map<String, dynamic>> getBrandById(String id, {String? token}) async {
    try {
      final response = await _dio.get(
        'brands/$id',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch all cars from the backend.
  ///
  /// Calls `GET /api/cars`
  /// Returns a list of available cars with their details.
  Future<Map<String, dynamic>> getCars({String? token}) async {
    try {
      final response = await _dio.get(
        'cars',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch a specific car by ID from the backend.
  ///
  /// Calls `GET /api/cars/:id`
  /// Returns the car details including brandId and other info.
  Future<Map<String, dynamic>> getCarById(String id, {String? token}) async {
    try {
      final response = await _dio.get(
        'cars/$id',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Location Data (Cities, Airports, Terminals)
  // ---------------------------------------------------------------------------

  /// Fetch all cities from the backend.
  ///
  /// Calls `GET /api/cities`
  Future<Map<String, dynamic>> getCities({String? token}) async {
    try {
      final response = await _dio.get(
        'cities',
        options: token != null ? _authOptions(token) : null,
      );
      if (kDebugMode) {
        debugPrint('🚀 🌐 API │ GET Cities Response: ${response.data}');
      }
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch all airports from the backend.
  ///
  /// Calls `GET /api/airports`
  Future<Map<String, dynamic>> getAirports({String? token}) async {
    try {
      final response = await _dio.get(
        'airports',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch all terminals from the backend.
  ///
  /// Calls `GET /api/terminals`
  Future<Map<String, dynamic>> getTerminals({String? token}) async {
    try {
      final response = await _dio.get(
        'terminals',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Banners
  // ---------------------------------------------------------------------------

  /// Fetch all active banners from the backend for the homepage.
  ///
  /// Calls `GET /api/banners`
  /// Returns a list of banners with their details.
  Future<Map<String, dynamic>> getBanners({String? token}) async {
    try {
      final response = await _dio.get(
        'banners',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Zones
  // ---------------------------------------------------------------------------

  /// Fetch all zones from the backend.
  ///
  /// Calls `GET /api/zone/zones`
  Future<Map<String, dynamic>> getZones({String? token}) async {
    try {
      final response = await _dio.get(
        'zone/zones',

        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal Helpers
  // ---------------------------------------------------------------------------

  /// Extract a success map from a Dio [Response].
  Map<String, dynamic> _success(Response response) {
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return {'success': true, ...data};
    }
    return {'success': true, 'data': data};
  }

  /// Convert any error into a consistent map.
  Map<String, dynamic> _handleError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      final data = error.response?.data;

      String message;
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          message = 'Request timed out. Please try again.';
        case DioExceptionType.connectionError:
          message = 'No internet connection. Please check your network.';
        case DioExceptionType.badResponse:
          message =
              (data is Map<String, dynamic>
                      ? (data['message'] ?? data['error'])
                      : null)
                  as String? ??
              'Server error ($statusCode)';
        case DioExceptionType.cancel:
          message = 'Request was cancelled.';
        default:
          message = 'Something went wrong. Please try again.';
      }

      debugPrint('🌐 API │ Error [$statusCode]: $message');
      return {
        'success': false,
        'statusCode': statusCode,
        'message': message,
        if (data is Map<String, dynamic>) ...data,
      };
    }

    debugPrint('🌐 API │ Unexpected error: $error');
    return {
      'success': false,
      'message': 'Something went wrong. Please try again.',
    };
  }

  // ---------------------------------------------------------------------------
  // Special Content (Promo Codes)
  // ---------------------------------------------------------------------------

  /// Validate a promo code by code string.
  /// Calls POST /api/special-content/validate with body { "code": "SAVE10" }
  Future<Map<String, dynamic>> validatePromoCode({
    required String code,
    String? companyEmail,
    String? token,
  }) async {
    try {
      final data = {
        'code': code,
        if (companyEmail != null && companyEmail.isNotEmpty)
          'companyEmail': companyEmail,
      };
      final response = await _dio.post(
        'special-content/validate',
        data: data,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Increment the usage count of a special content (promo code).
  Future<Map<String, dynamic>> incrementSpecialContentCount({
    required String id,
    String? token,
  }) async {
    try {
      final response = await _dio.patch(
        'special-content/$id/increment',
        data: {'usedCount': 1},
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch the current VAT percentage.
  /// Calls GET /api/vat
  Future<Map<String, dynamic>> getVat({String? token}) async {
    try {
      final response = await _dio.get(
        'vat',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }
}
