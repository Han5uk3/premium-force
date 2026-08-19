import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/api_result.dart';
import 'package:premium_force_main/api/v2_client.dart';
import 'package:premium_force_main/models/v2/available_vehicle.dart';
import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/models/v2/booking_v2.dart';
import 'package:premium_force_main/models/v2/chauffeur_options.dart';
import 'package:premium_force_main/models/v2/checkout_models.dart';
import 'package:premium_force_main/models/v2/geo_models.dart';
import 'package:premium_force_main/models/v2/session_models.dart';
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
class BookingApiV2 extends V2ApiClient {
  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

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

  BookingApiV2._internal();

  // ---------------------------------------------------------------------------
  // Common — cities & geo resolution
  // ---------------------------------------------------------------------------

  /// All bookable cities.
  Future<ApiResult<List<CityV2>>> getCities() {
    return request(
      () => dio.get('cities'),
      parse: (payload) => V2ApiClient.listOf(payload, const [
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
    return request(
      () => dio.get(
        'airports',
        queryParameters: {if (cityId != null) 'cityId': cityId},
      ),
      parse: (payload) => V2ApiClient.listOf(payload, const [
        'airports',
        'data',
        'items',
      ]).map(AirportV2.fromJson).toList(),
    );
  }

  /// Terminals, optionally scoped to an airport.
  Future<ApiResult<List<TerminalV2>>> getTerminals({String? airportId}) {
    return request(
      () => dio.get(
        'terminals',
        queryParameters: {if (airportId != null) 'airportId': airportId},
      ),
      parse: (payload) => V2ApiClient.listOf(payload, const [
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
    return request(
      () => dio.post('geo/resolve-city', data: {'lat': lat, 'lng': lng}),
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
    return request(
      () => dio.post('resolve-zone', data: {'lat': lat, 'lng': lng}),
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
    return request(
      () => dio.get('chauffeur/options'),
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
      () => dio.post(
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
      () => dio.post(
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
      () => dio.post(
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
    return request(
      () => dio.get(
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
        debugPrint(
          '🎙️ v2 │ Voice note gone from $voiceNotePath — sending without it',
        );
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
      () => dio.patch('bookings/session/vehicle', data: body),
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
      () => dio.patch(
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
    return request(
      () => dio.get('bookings/session/checkout'),
      parse: (payload) => CheckoutDetails.fromJson(asMap(payload)),
    );
  }

  /// Apply a coupon and get the recalculated checkout back.
  Future<ApiResult<CheckoutDetails>> applyCoupon(String couponCode) {
    return request(
      () => dio.post(
        'bookings/session/coupon',
        data: {'couponCode': couponCode.trim()},
      ),
      parse: (payload) => CheckoutDetails.fromJson(asMap(payload)),
    );
  }

  /// Remove the applied coupon and get the recalculated checkout back.
  Future<ApiResult<CheckoutDetails>> removeCoupon() {
    return request(
      () => dio.delete('bookings/session/coupon'),
      parse: (payload) => CheckoutDetails.fromJson(asMap(payload)),
    );
  }

  /// Confirm the draft.
  ///
  /// Creates the booking row *before* any money moves: either `confirmed`
  /// outright (zero total) or `pending_payment` alongside a payment transaction,
  /// in which case the response carries the PayTabs SDK parameters to use.
  Future<ApiResult<ConfirmBookingResult>> confirmBooking() {
    return request(
      () => dio.post('bookings/session/confirm'),
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
    return request(
      () => dio.post(
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
    return request(
      () => dio.get(
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
    return request(
      () => dio.get('bookings/$bookingId'),
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
    return request(
      () => dio.post(
        'bookings/$bookingId/cancel',
        data: {
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      ),
      parse: (payload) => BookingCancellation.fromJson(asMap(payload)),
    );
  }

  /// Download the ZATCA-compliant VAT invoice PDF for a booking.
  ///
  /// The endpoint streams `application/pdf` rather than the usual JSON envelope,
  /// so the response is read as bytes and the outcome is judged from the status
  /// code and content type. A rejection still arrives as JSON — an unpaid
  /// booking, or one belonging to somebody else — and its message is unwrapped
  /// so the caller can show it verbatim.
  ///
  /// [invoicePath] is the booking's own `invoiceUrl` when it carries one; it is
  /// an absolute API path, which Dio resolves against the host rather than the
  /// `/api/v2/` base.
  Future<ApiResult<Uint8List>> downloadInvoice({
    required String bookingId,
    String? invoicePath,
  }) async {
    final path = (invoicePath?.trim().isNotEmpty ?? false)
        ? invoicePath!.trim()
        : 'bookings/$bookingId/invoice';

    try {
      final response = await dio.get<List<int>>(
        path,
        options: Options(
          responseType: ResponseType.bytes,
          // The PDF is generated on demand, which takes longer than a read.
          receiveTimeout: const Duration(seconds: 45),
          headers: {'Accept': 'application/pdf'},
        ),
      );

      final status = response.statusCode ?? 0;
      final bytes = response.data;

      if (status >= 400 || bytes == null || bytes.isEmpty) {
        return ApiResult<Uint8List>.failure(
          _invoiceErrorMessage(bytes) ?? V2ApiClient.statusMessage(status),
          statusCode: status,
        );
      }

      // A JSON body here means the server rejected the request while still
      // answering 200 — the envelope's `success: false` case.
      final contentType = response.headers.value('content-type') ?? '';
      if (!contentType.toLowerCase().contains('pdf')) {
        return ApiResult<Uint8List>.failure(
          _invoiceErrorMessage(bytes) ?? 'Invoice is not available yet.',
          statusCode: status,
        );
      }

      debugPrint('🧾 v2 │ invoice downloaded (${bytes.length} bytes)');
      return ApiResult<Uint8List>.ok(Uint8List.fromList(bytes));
    } on DioException catch (error) {
      return ApiResult<Uint8List>.failure(
        V2ApiClient.dioMessage(error),
        statusCode: error.response?.statusCode,
      );
    } catch (error) {
      debugPrint('💥 v2 │ invoice download failed: $error');
      return ApiResult<Uint8List>.failure(
        'Could not open the invoice. Please try again.',
      );
    }
  }

  /// Read the `message` out of an error body that arrived where a PDF was
  /// expected.
  static String? _invoiceErrorMessage(List<int>? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      return pickString(asMap(decoded), const ['message', 'error']);
    } catch (_) {
      return null;
    }
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
    return request(
      send,
      parse: (payload) => BookingSession.fromJson(asMap(payload)),
    );
  }
}
