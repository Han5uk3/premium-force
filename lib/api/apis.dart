import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_main/models/user.dart';
import 'package:premium_force_main/models/booking_request_model.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/services/google_sign_in_service.dart';

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
  // Singleton + Dio instance
  // --------http://ec2-54-252-191-113.ap-southeast-2.compute.amazonaws.com:5000/api/-------------------------------------------------------------------

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
        onError: (DioException e, ErrorInterceptorHandler handler) async {
          // Check if error is 401 Unauthorized
          if (e.response?.statusCode == 401) {
            final provider = UserLocalStorage.getLoginProvider();
            debugPrint('🔄 API │ Unauthorized. Provider: $provider');

            // --- PATH A: PHONE LOGIN (BACKEND FOCUSED) ---
            if (provider == 'phone' || provider == null) {
              final refreshToken = UserLocalStorage.getRefreshToken();
              if (refreshToken != null) {
                debugPrint('🔄 API │ Phone Auth. Refreshing backend tokens...');
                try {
                  final refreshDio = Dio(BaseOptions(baseUrl: _baseUrl));
                  final refreshResponse = await refreshDio.post(
                    '/otp/refresh-token',
                    data: {'refreshToken': refreshToken},
                  );

                  if (refreshResponse.statusCode == 200 &&
                      refreshResponse.data['success'] == true) {
                    final newAccess = refreshResponse.data['accessToken'];
                    final newRefresh = refreshResponse.data['refreshToken'];

                    if (newRefresh != null) {
                      await UserLocalStorage.saveTokens(
                        accessToken: newAccess,
                        refreshToken: newRefresh,
                      );
                    } else {
                      await UserLocalStorage.saveToken(newAccess);
                    }

                    debugPrint('✅ API │ Backend token refreshed. Retrying...');
                    e.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
                    return handler.resolve(await _dio.fetch(e.requestOptions));
                  }
                } catch (reErr) {
                  debugPrint('❌ API │ Phone refresh failure: $reErr');
                }
              }
            }

            // --- PATH B: GOOGLE LOGIN (LOCAL STORAGE FOCUSED) ---
            else if (provider == 'google') {
              debugPrint('🔄 API │ Google Auth. Triggering Silent NATIVE Refresh...');
              try {
                final silentRes = await GoogleSignInService.instance.signInSilently();
                if (silentRes?.idToken != null) {
                  await UserLocalStorage.saveSocialIdToken(silentRes!.idToken!);
                  
                  // For Google, we use the raw native token as our authorization bearer
                  // If the backend expects its own token, you should call googleAuth() here instead.
                  // For a "Local-Only" architecture, the native IdToken IS the bearer.
                  e.requestOptions.headers['Authorization'] = 'Bearer ${silentRes.idToken}';
                  
                  debugPrint('✅ API │ Native token refreshed locally. Retrying...');
                  return handler.resolve(await _dio.fetch(e.requestOptions));
                }
              } catch (googleErr) {
                debugPrint('❌ API │ Google silent refresh failure: $googleErr');
              }
            }

            // --- PATH C: APPLE LOGIN (LOCAL STORAGE FOCUSED) ---
            else if (provider == 'apple') {
              debugPrint('🔄 API │ Apple Auth. Re-authentication check needed...');
              // Note: Apple requires fresh user gesture or biometric often.
              // For a silent implementation, we'd rely on Keychain storage if not expired.
            }
          }
          // If not 401 or refresh failed, pass the error along
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
        'http://ec2-54-252-191-113.ap-southeast-2.compute.amazonaws.com:5000/auth/google',
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
        'http://ec2-54-252-191-113.ap-southeast-2.compute.amazonaws.com:5000/auth/apple',
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
      return _handleError(e);
    }
  }

  /// Delete a user by [id].
  Future<Map<String, dynamic>> deleteUser({
    required String id,
    String? token,
  }) async {
    try {
      final response = await _dio.delete(
        'users/$id',
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
    required String userId,
    required String fcmToken,
    String? token,
  }) async {
    try {
      final response = await _dio.post(
        'users/$userId/fcm-token',
        data: {'fcmToken': fcmToken},
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
        data: payload,
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
    final payload = {
      'fromCity': fromCityId,
      'toCity': toCityId,
      if (vehicleId != null) 'vehicleID': vehicleId,
    };
    if (kDebugMode) {
      debugPrint('🚀 🌐 API │ Filter Routes Request: $payload');
    }
    try {
      final response = await _dio.post(
        'routes/city-to-city/filter',
        data: payload,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      // Try again with the double slash if it fails?
      // Actually, let's keep it simple first.
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
      final fields = booking.toMap();

      // Handle files separately for FormData
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
        debugPrint('🚀 🌐 API │ FINAL FORM DATA (MULTIPART):');
        for (var element in formData.fields) {
          debugPrint('   📁 Field: ${element.key} -> ${element.value}');
        }
        for (var element in formData.files) {
          debugPrint('   📄 File: ${element.key} -> ${element.value.filename}');
        }
      }

      final response = await _dio.post(
        'bookings/',
        data: formData,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
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
        'bookings/',
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
      final response = await _dio.put(
        'bookings/$bookingId',
        data: {'bookingStatus': status},
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
    String? token,
  }) async {
    try {
      final response = await _dio.put(
        'hourly-bookings/$bookingId',
        data: {'bookingStatus': status},
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
      // Manual mapping to handle unique keys required by hourly-bookings API
      final fields = <String, dynamic>{};
      fields['hours'] =
          booking.category == 'chauffeured' && booking.serviceDuration == 0
          ? booking.estimatedHours?.toString() ?? '1'
          : (booking.serviceDuration == 1
                ? '8'
                : (booking.serviceDuration == 2 ? '12' : '1'));

      fields['pickupLat'] = booking.pickupLat ?? '';
      fields['pickuplong'] = booking.pickupLong ?? ''; // Lowercase 'l'
      fields['pickupAdddress'] = booking.pickupAddress ?? ''; // Triple 'd'
      fields['extraHours'] = '0';
      fields['category'] = booking.carclass ?? '';
      fields['model'] = booking.carmodel ?? '';
      fields['brand'] = booking.carbrand ?? '';
      fields['carName'] = booking.carName ?? '';
      fields['charge'] = booking.charge?.toString() ?? '0';
      fields['customerID'] = booking.customerID ?? '';
      fields['driverID'] = booking.driverID ?? 'null';
      fields['passsenrgersCount'] =
          booking.passengerCount ?? '1'; // typo: passsenrgersCount
      fields['passengerMobile'] = booking.passengerMobile ?? '';
      fields['carClass'] = booking.carclass ?? ''; // Upper C
      fields['specialRequestText'] = booking.specialRequestText ?? '';
      fields['bookingStatus'] = booking.bookingStatus ?? 'pending';
      fields['passengerNames'] = booking.passengerNames ?? '[]';
      fields['isActive'] = 'true';

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

      final response = await _dio.post(
        'hourly-bookings',
        data: formData,
        options: token != null ? _authOptions(token) : null,
      );
      return _success(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Response helpers
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
}
