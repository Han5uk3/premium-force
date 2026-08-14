import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/api_logger.dart';
import 'package:premium_force_main/api/api_result.dart';
import 'package:premium_force_main/models/v2/available_vehicle.dart';
import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/models/v2/chauffeur_options.dart';
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

  /// Largest voice note the vehicle-selection endpoint accepts.
  static const int _maxVoiceNoteBytes = 5 * 1024 * 1024;

  /// Audio types the endpoint allows, keyed by file extension.
  static const Map<String, String> _voiceNoteMimeTypes = {
    'mp3': 'audio/mpeg',
    'm4a': 'audio/mp4',
    'wav': 'audio/wav',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'webm': 'audio/webm',
    'flac': 'audio/flac',
  };

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
            // A multipart body is a one-shot stream, already consumed by the
            // attempt that 401'd; the retry needs its own copy.
            final data = e.requestOptions.data;
            if (data is FormData) {
              e.requestOptions.data = data.clone();
            }
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
  // Chauffeur — bookable durations
  // ---------------------------------------------------------------------------

  /// Durations the chauffeur product currently offers.
  ///
  /// Public endpoint — no session or token needed, so the duration picker can be
  /// populated as soon as the screen opens. The backend re-validates the chosen
  /// duration on session init.
  Future<ApiResult<ChauffeurOptions>> getChauffeurOptions() {
    return _request(
      () => _dio.get('chauffeur/options'),
      parse: (payload) => ChauffeurOptions.fromJson(asMap(payload)),
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

  /// Start a chauffeur draft (step 1).
  ///
  /// Chauffeur hire has no drop-off; [hours] is the booked duration, sent under
  /// the field [chauffeurType] dictates — `hours` for hourly hire, and
  /// `durationHours` for one of the fixed packages.
  Future<ApiResult<BookingSession>> initChauffeurSession({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required int hours,
    required DateTime pickupDateTime,
    ChauffeurType chauffeurType = ChauffeurType.hourly,
  }) {
    return _sessionRequest(
      () => _dio.post(
        BookingServiceType.chauffeur.sessionInitPath,
        data: {
          'chauffeurType': chauffeurType.wireValue,
          'pickupLat': pickupLat,
          'pickupLng': pickupLng,
          'pickupAddress': pickupAddress,
          chauffeurType.durationField: hours,
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

  /// Attach the chosen vehicle, ride notes and voice note to the draft (step 2).
  ///
  /// [voiceNotePath] is a local recording. When present the request is sent as
  /// multipart so the file rides along under `voiceNote`; the backend puts it on
  /// S3 and the returned draft carries the URL. Without a recording the request
  /// stays plain JSON, which is what the endpoint expects for text-only.
  ///
  /// A missing file is skipped rather than failing the step — the notes and the
  /// vehicle still matter more than the attachment.
  Future<ApiResult<BookingSession>> selectVehicle({
    required String vehicleId,
    String? rideNotes,
    String? voiceNotePath,
  }) async {
    final notes = rideNotes?.trim();
    final fields = <String, dynamic>{
      'vehicleId': vehicleId,
      if (notes != null && notes.isNotEmpty) 'rideNotes': notes,
    };

    Object body = fields;

    if (voiceNotePath != null && voiceNotePath.trim().isNotEmpty) {
      final file = File(voiceNotePath);

      if (!await file.exists()) {
        debugPrint('🎙️ v2 │ Voice note gone from $voiceNotePath — sending without it');
      } else if (await file.length() > _maxVoiceNoteBytes) {
        // Refused here rather than after uploading something the server will
        // only reject.
        debugPrint('🎙️ v2 │ Voice note over the 5 MB limit — not sent');
        return ApiResult<BookingSession>.failure(
          'Your voice note is too large. The maximum size is 5 MB.',
        );
      } else {
        body = FormData.fromMap({
          ...fields,
          'voiceNote': await _voiceNoteFile(file),
        });
      }
    }

    return _sessionRequest(
      () => _dio.patch('bookings/session/vehicle', data: body),
    );
  }

  /// Wrap a recording as a multipart part.
  ///
  /// The content type is set from the extension: the backend filters on audio
  /// types, and an unlabelled part would go up as `application/octet-stream`.
  static Future<MultipartFile> _voiceNoteFile(File file) {
    final filename = file.path.split(RegExp(r'[\\/]')).last;
    final extension = filename.split('.').last.toLowerCase();
    final mimeType = _voiceNoteMimeTypes[extension];

    return MultipartFile.fromFile(
      file.path,
      filename: filename,
      contentType: mimeType == null ? null : DioMediaType.parse(mimeType),
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

  /// Read the payment and booking status for [bookingNumber].
  ///
  /// Called after the PayTabs SDK returns; the server, not the SDK callback, is
  /// what decides whether the booking is confirmed. The endpoint is read-only —
  /// it mutates nothing and queries PayTabs live when the stored status is not
  /// yet captured — so it is safe to poll while a payment is clearing.
  Future<ApiResult<PaymentVerificationResult>> verifyPayment({
    required String bookingNumber,
  }) {
    return _request(
      () => _dio.post(
        'bookings/session/verify-payment',
        data: {'bookingNumber': bookingNumber},
      ),
      parse: (payload) => PaymentVerificationResult.fromJson(asMap(payload)),
    );
  }

  // ---------------------------------------------------------------------------
  // Bookings
  // ---------------------------------------------------------------------------

  /// Paginated booking history, filtered server-side.
  ///
  /// [tab] is sent as `status` using its English [BookingTab.wireValue]
  /// (`upcoming`, `ongoing`, …); omitting it asks for `all`, every status at
  /// once. The endpoint rejects anything else, including the localised tab
  /// label and other casings.
  Future<ApiResult<BookingListPage>> getMyBookings({
    BookingTab? tab,
    int page = 1,
    int limit = 10,
  }) {
    return _request(
      () => _dio.get(
        'bookings/my-bookings',
        queryParameters: {
          'status': tab?.wireValue ?? BookingTab.allWireValue,
          'page': page,
          'limit': limit,
        },
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
  ///
  /// Only permitted while the booking is `pending_payment`, `confirmed` or
  /// `driver_assigned`; once the ride is under way the endpoint rejects it with
  /// a 400 whose message names the current state.
  ///
  /// A paid ride always raises a 100% refund; a zero-checkout ride cancels
  /// without touching the gateway. The reply is an acknowledgement carrying the
  /// refund outcome — not the booking, which has to be re-read.
  Future<ApiResult<BookingCancellation>> cancelBooking({
    required String bookingId,
    String? reason,
  }) {
    return _request(
      () => _dio.post(
        'bookings/$bookingId/cancel',
        data: {
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      ),
      parse: (payload) => BookingCancellation.fromJson(asMap(payload)),
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
