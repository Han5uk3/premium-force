import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_main/models/user.dart';
import 'package:premium_force_main/models/booking_request_model.dart';
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

    // ── Logging interceptor (debug mode only) ──────────────
    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          request: true,
          requestHeader: true,
          requestBody: true,
          responseHeader: false,
          responseBody: true,
          error: true,
          logPrint: (obj) => debugPrint('🌐 API │ $obj'),
        ),
      );
    }

    // ── Token Refresh Interceptor ──────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final token = UserLocalStorage.getToken();
          final currentUserId = UserLocalStorage.getUserId();
          if (token != null) debugPrint('🎫 Token │ $token');
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
                final refreshDio = Dio(BaseOptions(baseUrl: _baseUrl));
                final refreshResponse = await refreshDio.post(
                  'otp/refresh-token',
                  data: {'refreshToken': refreshToken},
                );

                if (refreshResponse.statusCode == 200 &&
                    refreshResponse.data != null) {
                  final data = refreshResponse.data;
                  final tokens = data['tokens'];

                  newAccess =
                      (tokens is Map
                              ? (tokens['accessToken'] ?? tokens['token'])
                              : (data['accessToken'] ?? data['token']))
                          as String?;
                  newRefresh =
                      (tokens is Map
                              ? (tokens['refreshToken'] ??
                                    tokens['refresh_token'])
                              : (data['refreshToken'] ?? data['refresh_token']))
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

              // Handle FormData retry by reconstructing logic if needed
              if (e.requestOptions.data is FormData) {
                final originalBooking =
                    e.requestOptions.extra['originalBooking']
                        as BookingRequestModel?;
                final originalType =
                    e.requestOptions.extra['originalType'] as String?;

                if (originalBooking != null) {
                  debugPrint('🔄 API │ Reconstructing FormData for retry...');
                  final formData = originalType == 'hourly'
                      ? await _buildHourlyFormData(originalBooking)
                      : await _buildNormalFormData(originalBooking);
                  e.requestOptions.data = formData;
                }
              }

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
  Future<Map<String, dynamic>> verifyOtp({
    required String countryCode,
    required String phoneNumber,
    required String otp,
    String purpose = 'login',
  }) async {
    try {
      final response = await _dio.post(
        'otp/verify-otp',
        data: {
          'countryCode': countryCode,
          'phoneNumber': phoneNumber,
          'otp': otp,
          'purpose': purpose,
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
  Future<Map<String, dynamic>> googleAuth({required String idToken}) async {
    try {
      final data = {'idToken': idToken};

      debugPrint('🔐 Google Auth │ Sending data: $data');

      final response = await _dio.post(
        'https://api.premiumforcegroup.com/auth/google',
        data: data,
      );

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
  Future<Map<String, dynamic>> appleAuth({required String idToken}) async {
    try {
      final data = {'idToken': idToken};

      debugPrint('🍎 Apple Auth │ Sending data: $data');

      final response = await _dio.post(
        'https://api.premiumforcegroup.com/auth/apple',
        data: data,
      );

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
  }) async {
    try {
      final formData = FormData.fromMap({
        'username': username,
        'email': email,
        'countryCode': countryCode,
        'phoneNumber': phoneNumber,
        'role': role,
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
          );
        }
      }
      return _handleError(e);
    }
  }

  /// Fetch all users.
  Future<Map<String, dynamic>> getAllUsers({String? token}) async {
    try {
      final response = await _dio.get(
        'users',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
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
  /// Calls `PUT /api/users/:id/fcm-token`
  Future<Map<String, dynamic>> updateFcmToken({
    required String userid,
    required String fcmToken,
    String? token,
  }) async {
    try {
      final response = await _dio.put(
        'users/$userid/fcm-token',
        data: {'fcmToken': fcmToken},
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Check if a user with the given [email] exists in the database.
  ///
  /// Calls `GET /users/check-email?email=...`
  /// Returns success=true if email exists, success=false if it doesn't.
  Future<Map<String, dynamic>> checkEmailExists({required String email}) async {
    try {
      final response = await _dio.get(
        'users/check-email',
        queryParameters: {'email': email},
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Car Data (Categories, Brands, Cars)
  // ---------------------------------------------------------------------------

  /// Fetch all car categories from the backend.
  ///
  /// Calls `GET /api/categories`
  /// Returns a list of categories with their details.
  Future<Map<String, dynamic>> getCategories({String? token}) async {
    try {
      final response = await _dio.get(
        'categories',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch all car brands from the backend.
  ///
  /// Calls `GET /api/brands`
  /// Returns a list of brands with their details.
  Future<Map<String, dynamic>> getBrands({String? token}) async {
    try {
      final response = await _dio.get(
        'brands',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

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
  // FCM / Push Notifications
  // ---------------------------------------------------------------------------

  /// Register or update the [fcmToken] for the user identified by [userId].
  ///
  /// Call this after login / signup once you have both a valid user id and an
  /// FCM token.
  Future<Map<String, dynamic>> registerFcmToken({
    required String userid,
    required String fcmToken,
    String? token,
  }) async {
    try {
      final response = await _dio.post(
        'users/$userid/fcm-token',
        data: {'fcmToken': fcmToken, 'userid': userid},
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Routes & Pricing
  // ---------------------------------------------------------------------------

  /// Fetch the price for a specific route and vehicle.
  ///
  /// Calls `GET /api/routes/FromcityToCity/vehicleRoutePrice`
  Future<Map<String, dynamic>> getRoutePrice({
    required String fromCityId,
    required String toCityId,
    required String vehicleId,
    String? token,
  }) async {
    final payload = {
      'fromCity': fromCityId,
      'toCity': toCityId,
      'vehicleID': vehicleId,
    };
    if (kDebugMode) {
      debugPrint('🚀 🌐 API │ Route Price Request: $payload');
    }
    try {
      final response = await _dio.get(
        'routes/FromcityToCity/vehicleRoutePrice',
        queryParameters: payload,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Filter routes to check availability between cities.
  ///
  /// Calls `POST /api/routes/city-to-city/filter` (Note the double slash in Postman might be a typo)
  /// We'll use the canonical path.
  Future<Map<String, dynamic>> filterRoutes({
    required String fromCityId,
    required String toCityId,
    String? vehicleId,
    String? token,
  }) async {
    final query = {
      'fromCity': fromCityId,
      'toCity': toCityId,
      if (vehicleId != null) 'vehicleID': vehicleId,
    };
    if (kDebugMode) {
      debugPrint('🚀 🌐 API │ Filter Routes Request: $query');
    }
    try {
      final response = await _dio.get(
        'routes',
        queryParameters: query,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// NEW: Get vehicles and routes between cities
  /// Calls `GET /api/routes/between/{fromCityId}/{toCityId}/cars`
  Future<Map<String, dynamic>> getRoutesBetweenCities({
    required String fromCityId,
    required String toCityId,
    String? token,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '🚀 🌐 API │ GET Routes Between Cities: $fromCityId to $toCityId',
      );
    }
    try {
      final response = await _dio.get(
        'routes/between/$fromCityId/$toCityId/cars',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch routes by cities and vehicle.
  /// This is another way to check if a route exists.
  Future<Map<String, dynamic>> getRouteByCities({
    required String fromCityId,
    required String toCityId,
    String? vehicleId,
    String? token,
  }) async {
    try {
      // Based on findstr output, there might be a simple routes filter
      final response = await _dio.get(
        'routes',
        queryParameters: {
          'fromCity': fromCityId,
          'toCity': toCityId,
          if (vehicleId != null) 'vehicleID': vehicleId,
        },
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch hourly pricing specifically for a vehicle.
  ///
  /// Calls `GET /api/hourly-routes/vehicle/:vehicleId`
  Future<Map<String, dynamic>> getHourlyPriceForVehicle({
    required String vehicleId,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        'hourly-routes/vehicle/$vehicleId',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch all hourly routes for calculations.
  ///
  /// Calls `GET /api/hourly-routes`
  Future<Map<String, dynamic>> getHourlyRoutes({String? token}) async {
    try {
      final response = await _dio.get(
        'hourly-routes',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch cars available for a specific hourly duration.
  ///
  /// Calls `GET /api/hourly-routes/cars/{hours}`
  Future<Map<String, dynamic>> getHourlyCars({
    required int hours,
    String? token,
  }) async {
    if (kDebugMode) {
      debugPrint('🚀 🌐 API │ GET Hourly Cars for: $hours hours');
    }
    try {
      final response = await _dio.get(
        'hourly-routes/cars/$hours',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Create a new booking.
  ///
  /// Calls `POST /api/bookings`
  Future<Map<String, dynamic>> createBooking({
    required BookingRequestModel booking,
    String? token,
  }) async {
    if (kDebugMode) {
      debugPrint('🚀 🌐 API │ Create Booking Payload: ${booking.toMap()}');
    }
    try {
      final formData = await _buildNormalFormData(booking);

      final response = await _dio.post(
        'bookings',
        data: formData,
        options: (token != null ? _authOptions(token) : Options()).copyWith(
          extra: {'originalBooking': booking, 'originalType': 'normal'},
        ),
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<FormData> _buildNormalFormData(BookingRequestModel booking) async {
    final fields = booking.toMap();
    fields.remove('carImage'); // Remove text path to prevent conflict

    // Sanitize distance (Postman expects numeric-only string)
    if (fields['distance'] != null) {
      fields['distance'] = fields['distance']
          .toString()
          .replaceAll(RegExp(r'[^0-9.]'), '')
          .trim();
    }

    // Format charge to 2 decimal places string (e.g. 95.00)
    if (fields['charge'] != null) {
      if (fields['charge'] is num) {
        fields['charge'] = (fields['charge'] as num).toStringAsFixed(2);
      } else {
        fields['charge'] = fields['charge'].toString();
      }
    }

    // Ensure driverID is not sent if it's 'null' string
    if (fields['driverID'] == 'null') {
      fields.remove('driverID');
    }

    // Ensure customer info is present
    fields['customerID'] ??= booking.customerID ?? '';
    fields['customerName'] ??= booking.customerName ?? '';
    fields['customer_name'] = fields['customerName']; // Snake case fallback
    fields['username'] = fields['customerName']; // Backend user field fallback

    // Ensure numeric fields are strings for FormData consistency
    if (fields['passengerCount'] != null) {
      fields['passengerCount'] = fields['passengerCount'].toString();
    }
    if (fields['discountPercentage'] != null) {
      fields['discountPercentage'] = fields['discountPercentage'].toString();
    }
    if (fields['vat'] != null) {
      fields['vat'] = fields['vat'].toString();
    }

    // Handle files separately for FormData
    if (booking.specialRequestAudio != null) {
      fields['specialRequestAudio'] = await MultipartFile.fromFile(
        booking.specialRequestAudio!.path,
        filename: 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
    }

    // Postman uses lowercase 'carimage'
    if (booking.carImage != null) {
      fields['carimage'] = await MultipartFile.fromFile(
        booking.carImage!.path,
        filename: 'car_image.jpg',
      );
    }

    // Initialize extra hours/payment data for new bookings to ensure they start clean
    fields['extrahours'] = '0';
    fields['extraPayment'] = '0';
    fields['extraDiscount'] = '0';
    fields['extraVat'] = '0';
    fields['extraOrderID'] = '';
    fields['extraTransactionID'] = '';
    fields['extraPaymentCompleted'] = 'false';

    final formData = FormData.fromMap(fields);

    if (kDebugMode) {
      debugPrint('🚀 🌐 API │ FINAL FORM DATA (MULTIPART):');
      for (var element in formData.fields) {
        debugPrint('   📁 Field: ${element.key} -> ${element.value}');
      }
      for (var element in formData.files) {
        debugPrint('   📄 File: ${element.key} -> ${element.value.filename}');
      }
    }
    return formData;
  }

  /// Fetch all bookings for a specific customer.
  ///
  /// Calls `GET /api/bookings/customer/:customerId`
  Future<Map<String, dynamic>> getBookingsByCustomerId({
    required String customerId,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        'bookings/customer/$customerId',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch all hourly bookings for a specific customer.
  ///
  /// Calls `GET /api/hourly-bookings/customer/:customerId`
  Future<Map<String, dynamic>> getHourlyBookingsByCustomerId({
    required String customerId,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        'hourly-bookings/customer/$customerId',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch all bookings for a specific driver.
  ///
  /// Calls `GET /api/bookings/driver/:driverId`
  Future<Map<String, dynamic>> getBookingsByDriverId({
    required String driverId,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        'bookings/driver/$driverId',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch all bookings.
  ///
  /// Calls `GET /api/bookings`
  Future<Map<String, dynamic>> getAllBookings({String? token}) async {
    try {
      final response = await _dio.get(
        'bookings',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Update an existing booking's status.
  Future<Map<String, dynamic>> updateBookingStatus({
    required String bookingId,
    required String status,
    String? token,
  }) async {
    try {
      final response = await _dio.patch(
        'bookings/$bookingId/status',
        data: {'status': status},
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Cancel a booking using the unified cancellation endpoint.
  Future<Map<String, dynamic>> cancelBooking({
    required String bookingId,
    String? token,
  }) async {
    try {
      final response = await _dio.patch(
        'users/cancel/booking/$bookingId',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Update an existing hourly booking's status.
  Future<Map<String, dynamic>> updateHourlyBookingStatus({
    required String bookingId,
    required String status,
    String? transactionReference,
    String? token,
  }) async {
    try {
      final data = <String, dynamic>{'bookingStatus': status};
      if (transactionReference != null) {
        data['transactionReference'] = transactionReference;
      }
      final response = await _dio.patch(
        'hourly-bookings/$bookingId/status',
        data: data,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Update extra payment details for an hourly booking.
  Future<Map<String, dynamic>> updateHourlyExtraPayment({
    required String bookingId,
    required String extraOrderID,
    required String extraTransactionID,
    required double extraPayment,
    required double extraDiscount,
    required double extraVat,
    required String extraPaymentCompleted,
    String? token,
  }) async {
    try {
      final data = <String, dynamic>{
        'extraOrderID': extraOrderID,
        'extraTransactionID': extraTransactionID,
        'extraPayment': extraPayment.toString(),
        'extraDiscount': extraDiscount.toString(),
        'extraVat': extraVat.toString(),
        'extraPaymentCompleted': extraPaymentCompleted,
      };
      final response = await _dio.patch(
        'hourly-bookings/$bookingId/status',
        data: data,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Create an hourly booking (specifically for chauffeur category).
  ///
  /// Calls `POST /api/hourly-bookings`
  Future<Map<String, dynamic>> createHourlyBooking({
    required BookingRequestModel booking,
    String? token,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '🚀 🌐 API │ Create Hourly Booking Payload: ${booking.toMap()}',
      );
    }
    try {
      final formData = await _buildHourlyFormData(booking);

      final response = await _dio.post(
        'hourly-bookings',
        data: formData,
        options: (token != null ? _authOptions(token) : Options()).copyWith(
          extra: {'originalBooking': booking, 'originalType': 'hourly'},
        ),
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  Future<FormData> _buildHourlyFormData(BookingRequestModel booking) async {
    // Manual mapping to handle unique keys required by hourly-bookings API
    final fields = <String, dynamic>{};

    // Use estimatedHours if available (e.g. 4), otherwise calculate from serviceDuration
    if (booking.estimatedHours != null && booking.estimatedHours != 0) {
      fields['hours'] = booking.estimatedHours.toString();
    } else {
      fields['hours'] =
          booking.category == 'chauffeured' && booking.serviceDuration == 0
          ? booking.estimatedHours?.toString() ?? '1'
          : (booking.serviceDuration == 1
                ? '8'
                : (booking.serviceDuration == 2 ? '12' : '1'));
    }

    fields['pickupLat'] = booking.pickupLat ?? '';
    fields['pickupLong'] = booking.pickupLong ?? '';
    fields['pickuplong'] =
        booking.pickupLong ?? ''; // Postman typo compatibility
    fields['pickupAddress'] = booking.pickupAddress ?? '';
    fields['pickupAdddress'] =
        booking.pickupAddress ?? ''; // Postman typo compatibility
    fields['pickupDateTime'] = booking.pickupdatetime ?? '';
    fields['model'] = booking.carmodel ?? '';
    fields['categoryID'] = booking.categoryID ?? '';
    fields['brandID'] = booking.brandID ?? '';
    fields['carID'] = booking.carID ?? '';
    fields['cityID'] = booking.cityID ?? '';
    fields['charge'] = booking.charge?.toStringAsFixed(2) ?? '0.00';
    fields['customerID'] = booking.customerID ?? '';
    fields['customerName'] = booking.customerName ?? '';
    fields['customer_name'] = booking.customerName ?? ''; // Snake case fallback
    fields['extrahours'] = '0'; // Default value as requested
    fields['extraPayment'] = '0';
    fields['extraDiscount'] = '0';
    fields['extraVat'] = '0';
    fields['extraOrderID'] = '';
    fields['extraTransactionID'] = '';
    fields['extraPaymentCompleted'] = 'false';
    fields['username'] =
        booking.customerName ?? ''; // Backend user field fallback
    fields['passengerCount'] = booking.passengerCount ?? '1';
    fields['passsenrgersCount'] =
        booking.passengerCount ?? '1'; // Postman typo compatibility
    fields['passengerMobile'] = booking.passengerMobile ?? '';
    fields['carClass'] = booking.carclass ?? '';
    fields['transactionID'] = booking.transactionID ?? '';
    fields['orderID'] = booking.orderID ?? '';
    fields['passengerNames'] = booking.passengerNames ?? '[]';

    // Legacy/Additional fields for safety
    fields['extraHours'] = '1';
    fields['category'] = booking.carclass ?? '';
    fields['brand'] = booking.carbrand ?? '';
    fields['carName'] = booking.carName ?? '';
    fields['driverID'] = booking.driverID ?? 'null';
    fields['specialRequestText'] = booking.specialRequestText ?? '';
    fields['bookingStatus'] = booking.bookingStatus ?? 'pending';
    fields['isActive'] = 'true';

    if (booking.discountPercentage != null) {
      fields['discountPercentage'] = booking.discountPercentage.toString();
    }

    // Additional fields from Postman
    fields['extraTransactionID'] = 'null';
    fields['extraOrderID'] = 'null';
    fields['extraPayment'] = 'null';
    fields['startedAt'] = DateTime.now().toIso8601String();
    fields['stoppedAt'] = DateTime.now().toIso8601String();
    fields['extraDiscount'] = 'null';
    fields['extraVat'] = 'null';
    fields['extraPaymentCompleted'] = 'null';
    fields['vat'] = booking.vat?.toString() ?? '0';

    // Handle files
    if (booking.specialRequestAudio != null) {
      fields['specialRequestAudio'] = await MultipartFile.fromFile(
        booking.specialRequestAudio!.path,
        filename: 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
      );
    }
    if (booking.carImage != null) {
      fields['carImage'] = await MultipartFile.fromFile(
        booking.carImage!.path,
        filename: 'car_image.jpg',
      );
    }

    final formData = FormData.fromMap(fields);

    if (kDebugMode) {
      debugPrint('🚀 🌐 API │ FINAL HOURLY FORM DATA (MULTIPART):');
      for (var element in formData.fields) {
        debugPrint('   📁 Field: ${element.key} -> ${element.value}');
      }
      for (var element in formData.files) {
        debugPrint('   📄 File: ${element.key} -> ${element.value.filename}');
      }
    }
    return formData;
  }

  // ---------------------------------------------------------------------------
  // Reviews
  // ---------------------------------------------------------------------------

  /// Add a review for a completed booking.
  ///
  /// Calls `POST /api/reviews`
  Future<Map<String, dynamic>> addReview({
    required String bookingID,
    required String driverID,
    required int rate,
    String? reviewText,
    String? token,
  }) async {
    try {
      final data = <String, dynamic>{
        'bookingID': bookingID,
        'driverID': driverID,
        'rate': rate,
        'isActive': true,
      };
      if (reviewText != null && reviewText.trim().isNotEmpty) {
        data['reviewText'] = reviewText.trim();
      }
      final response = await _dio.post(
        'reviews',
        data: data,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Get all reviews.
  ///
  /// Calls `GET /api/reviews`
  Future<Map<String, dynamic>> getReviews({String? token}) async {
    try {
      final response = await _dio.get(
        'reviews',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

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

  /// Fetch zone pricing for a specific route.
  ///
  /// Calls `GET /api/zonePrice/zone-pricing`
  Future<Map<String, dynamic>> getZonePrices({
    required String fromZoneId,
    required String toZoneId,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        'zonePrice/zone-pricing',
        queryParameters: {
          'zoneFromId': fromZoneId,
          'zoneToId': toZoneId,
        },
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

  /// Fetch all special content (promo codes).
  Future<Map<String, dynamic>> getSpecialContent({String? token}) async {
    try {
      final response = await _dio.get(
        'special-content',
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  /// Fetch a specific promo code by its code string.
  /// Calls GET /api/special-content/code/:code
  Future<Map<String, dynamic>> getSpecialContentByCode({
    required String code,
    String? token,
  }) async {
    try {
      final response = await _dio.get(
        'special-content/code/$code',
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
