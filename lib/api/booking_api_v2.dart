import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/api_logger.dart';
import 'package:premium_force_main/api/api_result.dart';
import 'package:premium_force_main/models/v2/available_vehicle.dart';
import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/models/v2/checkout_models.dart';
import 'package:premium_force_main/models/v2/geo_models.dart';
import 'package:premium_force_main/models/v2/session_models.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/utils/json_utils.dart';

/// Client for the v2 booking API.
///
/// The v2 surface is server-session driven: the backend holds the booking draft
/// in Redis (keyed by user, 1-hour TTL) and every step returns the updated
/// draft. Pricing, availability, and the payment amount are all decided
/// server-side, so this client never computes a fare or an amount.
///
/// Auth is the same JWT the v1 [ApiService] already stores — only the base path
/// differs (`/api/v2/` vs `/api/`), so both clients coexist during migration.
///
/// Usage:
/// ```dart
/// final api = BookingApiV2();
/// final session = await api.initPrivateTransferSession(...);
/// if (!session.success) showError(session.message);
/// ```
class BookingApiV2 {
  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  static const String _baseUrl = 'https://api.premiumforcegroup.com/api/v2/';

  /// Token refresh still lives on the v1 auth surface (no `v2` prefix).
  static const String _refreshUrl = 'https://api.premiumforcegroup.com/api/';

  // ---------------------------------------------------------------------------

  static final BookingApiV2 _instance = BookingApiV2._internal();
  factory BookingApiV2() => _instance;

  late final Dio _dio;

  BookingApiV2._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
        // Session endpoints use 404 to mean "not serviceable", which is a
        // normal outcome carrying a displayable message rather than a crash.
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    // Debug-only: payloads carry customer PII and, on confirm, live gateway
    // credentials. See BookingApiLogger for what it masks.
    if (kDebugMode) {
      _dio.interceptors.add(BookingApiLogger());
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = UserLocalStorage.getToken();
          if (token != null && options.headers['Authorization'] == null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode != 401) return handler.next(e);

          final newToken = await _refreshAccessToken();
          if (newToken == null) return handler.next(e);

          try {
            e.requestOptions.headers['Authorization'] = 'Bearer $newToken';
            final retried = await _dio.fetch(e.requestOptions);
            return handler.resolve(retried);
          } catch (_) {
            return handler.next(e);
          }
        },
      ),
    );
  }

  /// Exchange the stored refresh token for a new access token.
  ///
  /// Uses a bare [Dio] so the retry cannot re-enter this interceptor.
  Future<String?> _refreshAccessToken() async {
    final refreshToken = UserLocalStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: _refreshUrl,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      if (kDebugMode) refreshDio.interceptors.add(BookingApiLogger());

      final response = await refreshDio.post(
        'otp/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      final body = asMap(response.data);
      final tokens = pickMap(body, const ['tokens']).isNotEmpty
          ? pickMap(body, const ['tokens'])
          : pickMap(pickMap(body, const ['data']), const ['tokens']);

      final access =
          pickString(tokens, const ['accessToken', 'token']) ??
          pickString(body, const ['accessToken', 'token']);
      final refresh =
          pickString(tokens, const ['refreshToken', 'refresh_token']) ??
          pickString(body, const ['refreshToken', 'refresh_token']);

      if (access == null) return null;

      await UserLocalStorage.saveTokens(
        accessToken: access,
        refreshToken: refresh ?? refreshToken,
      );
      debugPrint('🔄 v2 │ Access token refreshed');
      return access;
    } catch (error) {
      debugPrint('🔄 v2 │ Token refresh failed: $error');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Common — cities & geo resolution
  // ---------------------------------------------------------------------------

  /// All bookable cities.
  Future<ApiResult<List<CityV2>>> getCities() {
    return _request(
      () => _dio.get('cities'),
      parse: (payload) => _listOf(payload, const [
        'cities',
        'data',
        'items',
      ]).map(CityV2.fromJson).toList(),
    );
  }

  /// Airports, optionally scoped to a city.
  ///
  /// Only needed when `GET /cities` does not nest them.
  Future<ApiResult<List<AirportV2>>> getAirports({String? cityId}) {
    return _request(
      () => _dio.get(
        'airports',
        queryParameters: {if (cityId != null) 'cityId': cityId},
      ),
      parse: (payload) => _listOf(payload, const [
        'airports',
        'data',
        'items',
      ]).map(AirportV2.fromJson).toList(),
    );
  }

  /// Terminals, optionally scoped to an airport.
  Future<ApiResult<List<TerminalV2>>> getTerminals({String? airportId}) {
    return _request(
      () => _dio.get(
        'terminals',
        queryParameters: {if (airportId != null) 'airportId': airportId},
      ),
      parse: (payload) => _listOf(payload, const [
        'terminals',
        'data',
        'items',
      ]).map(TerminalV2.fromJson).toList(),
    );
  }

  /// Resolve a coordinate to a serviced city.
  ///
  /// Every selected location is checked through this before the user may
  /// continue, so an out-of-service address is rejected at the point of entry
  /// rather than on session init.
  Future<ApiResult<ResolvedCity>> resolveCity({
    required double lat,
    required double lng,
  }) {
    return _request(
      () => _dio.post('geo/resolve-city', data: {'lat': lat, 'lng': lng}),
      parse: (payload) => ResolvedCity.fromJson(asMap(payload)),
      // A 404 here means "no serviced city covers this point" — a valid answer,
      // not a transport failure.
      onNotFound: (message) =>
          ResolvedCity(isServiceable: false, message: message),
    );
  }

  /// Resolve a coordinate to an active transfer zone.
  ///
  /// Private transfer requires both endpoints to land inside a configured zone.
  Future<ApiResult<ResolvedZone>> resolveZone({
    required double lat,
    required double lng,
  }) {
    return _request(
      () => _dio.post('resolve-zone', data: {'lat': lat, 'lng': lng}),
      parse: (payload) => ResolvedZone.fromJson(asMap(payload)),
      onNotFound: (message) =>
          ResolvedZone(isServiceable: false, message: message),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 — session initiation
  // ---------------------------------------------------------------------------

  /// Start an airport-transfer draft (step 1).
  ///
  /// [customerLat]/[customerLng]/[customerAddress] describe the non-airport end
  /// of the trip. They are sent as `dropOff*` for an arrival (airport → address)
  /// and as `pickup*` for a departure (address → airport); the airport side is
  /// always identified by [airportId]/[terminalId].
  Future<ApiResult<BookingSession>> initAirportTransferSession({
    required BookingServiceType serviceType,
    required String airportId,
    required String terminalId,
    required double customerLat,
    required double customerLng,
    required String customerAddress,
    required DateTime pickupDateTime,
    String? flightNumber,
  }) {
    assert(
      serviceType.isAirport,
      'initAirportTransferSession requires an airport service type',
    );

    final isArrival = serviceType == BookingServiceType.airportArrival;
    final prefix = isArrival ? 'dropOff' : 'pickup';

    return _sessionRequest(
      () => _dio.post(
        serviceType.sessionInitPath,
        data: {
          'transferSubType': serviceType.transferSubType,
          'airportId': airportId,
          'terminalId': terminalId,
          '${prefix}Lat': customerLat,
          '${prefix}Lng': customerLng,
          '${prefix}Address': customerAddress,
          if (flightNumber != null && flightNumber.trim().isNotEmpty)
            'flightNumber': flightNumber.trim(),
          'pickupDate': formatPickupDate(pickupDateTime),
          'pickupTime': formatPickupTime(pickupDateTime),
        },
      ),
    );
  }

  /// Start a private-transfer draft (step 1).
  ///
  /// The backend resolves both endpoints to transfer zones and rejects the
  /// request if either falls outside one.
  Future<ApiResult<BookingSession>> initPrivateTransferSession({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropOffLat,
    required double dropOffLng,
    required String dropOffAddress,
    required DateTime pickupDateTime,
  }) {
    return _sessionRequest(
      () => _dio.post(
        BookingServiceType.privateTransfer.sessionInitPath,
        data: {
          'pickupLat': pickupLat,
          'pickupLng': pickupLng,
          'pickupAddress': pickupAddress,
          'dropOffLat': dropOffLat,
          'dropOffLng': dropOffLng,
          'dropOffAddress': dropOffAddress,
          'pickupDate': formatPickupDate(pickupDateTime),
          'pickupTime': formatPickupTime(pickupDateTime),
        },
      ),
    );
  }

  /// Start a chauffeur (hourly) draft (step 1).
  ///
  /// Hourly hire has no drop-off; [hours] is the booked duration.
  Future<ApiResult<BookingSession>> initChauffeurSession({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required int hours,
    required DateTime pickupDateTime,
    String chauffeurType = 'hourly',
  }) {
    return _sessionRequest(
      () => _dio.post(
        BookingServiceType.chauffeur.sessionInitPath,
        data: {
          'chauffeurType': chauffeurType,
          'pickupLat': pickupLat,
          'pickupLng': pickupLng,
          'pickupAddress': pickupAddress,
          'hours': hours,
          'pickupDate': formatPickupDate(pickupDateTime),
          'pickupTime': formatPickupTime(pickupDateTime),
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 — vehicle selection
  // ---------------------------------------------------------------------------

  /// Vehicles available for the session's route, priced by the backend.
  Future<ApiResult<AvailableVehiclesResponse>> getAvailableVehicles({
    String? categoryId,
    String? brandId,
  }) {
    return _request(
      () => _dio.get(
        'bookings/session/vehicles',
        queryParameters: {
          if (categoryId != null && categoryId.isNotEmpty)
            'categoryId': categoryId,
          if (brandId != null && brandId.isNotEmpty) 'brandId': brandId,
        },
      ),
      parse: AvailableVehiclesResponse.fromJson,
    );
  }

  /// Attach the chosen vehicle and ride notes to the draft (step 2).
  ///
  /// The endpoint currently accepts notes as text only — the voice-note
  /// attachment from the previous flow has no field here yet.
  Future<ApiResult<BookingSession>> selectVehicle({
    required String vehicleId,
    String? rideNotes,
  }) {
    return _sessionRequest(
      () => _dio.patch(
        'bookings/session/vehicle',
        data: {
          'vehicleId': vehicleId,
          if (rideNotes != null && rideNotes.trim().isNotEmpty)
            'rideNotes': rideNotes.trim(),
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3 — passenger details
  // ---------------------------------------------------------------------------

  /// Save passenger details onto the draft (step 3).
  Future<ApiResult<BookingSession>> savePassengerDetails({
    required int passengersCount,
    required String passengerNames,
    required String passengerPhone,
  }) {
    return _sessionRequest(
      () => _dio.patch(
        'bookings/session/passenger',
        data: {
          'passengersCount': passengersCount,
          'passengerNames': passengerNames,
          'passengerPhone': passengerPhone,
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4 — checkout, coupons, confirmation
  // ---------------------------------------------------------------------------

  /// The authoritative price breakdown for the draft.
  Future<ApiResult<CheckoutDetails>> getCheckout() {
    return _request(
      () => _dio.get('bookings/session/checkout'),
      parse: (payload) => CheckoutDetails.fromJson(asMap(payload)),
    );
  }

  /// Apply a coupon and get the recalculated checkout back.
  Future<ApiResult<CheckoutDetails>> applyCoupon(String couponCode) {
    return _request(
      () => _dio.post(
        'bookings/session/coupon',
        data: {'couponCode': couponCode.trim()},
      ),
      parse: (payload) => CheckoutDetails.fromJson(asMap(payload)),
    );
  }

  /// Remove the applied coupon and get the recalculated checkout back.
  Future<ApiResult<CheckoutDetails>> removeCoupon() {
    return _request(
      () => _dio.delete('bookings/session/coupon'),
      parse: (payload) => CheckoutDetails.fromJson(asMap(payload)),
    );
  }

  /// Confirm the draft.
  ///
  /// Creates the booking row *before* any money moves: either `confirmed`
  /// outright (zero total) or `pending_payment` alongside a payment transaction,
  /// in which case the response carries the PayTabs SDK parameters to use.
  Future<ApiResult<ConfirmBookingResult>> confirmBooking() {
    return _request(
      () => _dio.post('bookings/session/confirm'),
      parse: (payload) => ConfirmBookingResult.fromJson(asMap(payload)),
    );
  }

  /// Ask the backend to settle the booking against the gateway.
  ///
  /// Called after the PayTabs SDK returns; the server, not the SDK callback, is
  /// what decides whether the booking is confirmed.
  Future<ApiResult<PaymentVerificationResult>> verifyPayment({
    required String bookingNumber,
    String? transactionReference,
  }) {
    return _request(
      () => _dio.post(
        'bookings/session/verify-payment',
        data: {
          'bookingNumber': bookingNumber,
          if (transactionReference != null && transactionReference.isNotEmpty)
            'transactionReference': transactionReference,
        },
      ),
      parse: (payload) => PaymentVerificationResult.fromJson(asMap(payload)),
    );
  }

  // ---------------------------------------------------------------------------
  // Bookings
  // ---------------------------------------------------------------------------

  /// Paginated booking history.
  ///
  /// [status] accepts `upcoming`, `ongoing`, `completed`, `cancelled`, or `all`.
  Future<ApiResult<BookingListPage>> getMyBookings({
    String status = 'all',
    int page = 1,
    int limit = 10,
  }) {
    return _request(
      () => _dio.get(
        'bookings/my-bookings',
        queryParameters: {'status': status, 'page': page, 'limit': limit},
      ),
      parse: (payload) => BookingListPage.fromJson(asMap(payload)),
    );
  }

  /// Full booking detail, including the progress timeline.
  Future<ApiResult<BookingV2>> getBookingById(String bookingId) {
    return _request(
      () => _dio.get('bookings/$bookingId'),
      parse: (payload) => BookingV2.fromJson(asMap(payload)),
    );
  }

  /// Cancel a booking and trigger the automated gateway refund.
  Future<ApiResult<BookingV2?>> cancelBooking({
    required String bookingId,
    String? reason,
  }) {
    return _request(
      () => _dio.post(
        'bookings/$bookingId/cancel',
        data: {
          if (reason != null && reason.trim().isNotEmpty) 'reason': reason,
        },
      ),
      // The response may echo the updated booking or just an acknowledgement.
      parse: (payload) {
        final map = asMap(payload);
        return map.isEmpty ? null : BookingV2.fromJson(map);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  /// Format a pickup date as the `YYYY-MM-DD` the API expects.
  ///
  /// Uses the local date components deliberately: the backend pairs this with
  /// the city's timezone, so converting to UTC here would shift the date.
  static String formatPickupDate(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day';
  }

  /// Format a pickup time as the 24-hour `HH:mm` the API expects.
  static String formatPickupTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // ---------------------------------------------------------------------------
  // Internal plumbing
  // ---------------------------------------------------------------------------

  /// Session endpoints all return the same draft envelope under `data`.
  Future<ApiResult<BookingSession>> _sessionRequest(
    Future<Response<dynamic>> Function() send,
  ) {
    return _request(
      send,
      parse: (payload) => BookingSession.fromJson(asMap(payload)),
    );
  }

  /// Run [send], unwrap the `{success, message, data}` envelope, and hand the
  /// inner payload to [parse].
  ///
  /// [onNotFound] converts a 404 into a successful result — used by the geo
  /// lookups, where "nothing matched" is an answer rather than an error.
  Future<ApiResult<T>> _request<T>(
    Future<Response<dynamic>> Function() send, {
    required T Function(dynamic payload) parse,
    T Function(String? message)? onNotFound,
  }) async {
    try {
      final response = await send();
      final body = asMap(response.data);
      final status = response.statusCode ?? 0;
      final message = pickString(body, const ['message', 'error']);
      // `success` may be absent on bare payloads; fall back to the status code.
      final succeeded =
          pickBool(body, const ['success']) ?? (status >= 200 && status < 300);

      if (!succeeded || status >= 400) {
        if (status == 404 && onNotFound != null) {
          debugPrint('🧭 v2 │ not serviceable → ${message ?? "(no message)"}');
          return ApiResult<T>.ok(onNotFound(message), message: message);
        }
        // A 2xx carrying `success: false` is easy to miss in the raw log, so
        // the interpreted outcome is recorded separately.
        debugPrint(
          '🚫 v2 │ rejected [$status] → ${message ?? _statusMessage(status)}',
        );
        return ApiResult<T>.failure(
          message ?? _statusMessage(status),
          statusCode: status,
        );
      }

      // Endpoints nest their payload under `data`; a few return it at the root.
      final payload = body.containsKey('data') ? body['data'] : body;
      final parsed = parse(payload);
      debugPrint('✅ v2 │ parsed $T${message == null ? '' : ' → $message'}');
      return ApiResult<T>.ok(parsed, message: message);
    } on DioException catch (error) {
      return ApiResult<T>.failure(
        _dioMessage(error),
        statusCode: error.response?.statusCode,
      );
    } catch (error, stackTrace) {
      // Almost always a shape mismatch between the response and the model.
      // Named explicitly because the v2 payloads are still being finalised, and
      // a parse failure must not crash the booking flow.
      debugPrint('💥 v2 │ failed to parse $T: $error');
      debugPrint('$stackTrace');
      return ApiResult<T>.failure('Something went wrong. Please try again.');
    }
  }

  static List<Map<String, dynamic>> _listOf(
    dynamic payload,
    List<String> keys,
  ) {
    if (payload is List) return asMapList(payload);
    return pickMapList(asMap(payload), keys);
  }

  static String _statusMessage(int statusCode) => switch (statusCode) {
    400 => 'Please check the details and try again.',
    401 => 'Your session has expired. Please sign in again.',
    403 => 'You are not allowed to perform this action.',
    404 => 'This service is not available for the selected details.',
    409 => 'This booking has already been processed.',
    422 => 'Please check the details and try again.',
    _ => 'Server error ($statusCode). Please try again.',
  };

  static String _dioMessage(DioException error) {
    final data = error.response?.data;
    final serverMessage = data is Map
        ? pickString(asMap(data), const ['message', 'error'])
        : null;
    if (serverMessage != null) return serverMessage;

    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'Request timed out. Please try again.',
      DioExceptionType.connectionError =>
        'No internet connection. Please check your network.',
      DioExceptionType.cancel => 'Request was cancelled.',
      _ => _statusMessage(error.response?.statusCode ?? 0),
    };
  }
}
