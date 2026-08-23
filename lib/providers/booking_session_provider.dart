import 'package:flutter/foundation.dart';
import 'package:premium_force_main/api/api_result.dart';
import 'package:premium_force_main/api/booking_api_v2.dart';
import 'package:premium_force_main/models/v2/available_vehicle.dart';
import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/models/v2/chauffeur_options.dart';
import 'package:premium_force_main/models/v2/checkout_models.dart';
import 'package:premium_force_main/models/v2/session_models.dart';

/// Which part of the flow is currently waiting on the network.
///
/// Distinguishing these lets each step show its own spinner instead of one
/// screen-wide loading flag.
enum SessionBusy {
  idle,
  initialising,
  loadingVehicles,
  savingVehicle,
  savingPassenger,
  loadingCheckout,
  applyingCoupon,
  confirming,
  verifyingPayment,
}

/// Client-side mirror of the server-held booking draft.
///
/// Every mutation goes through the API and the response *replaces* local state,
/// so the screen always renders what the backend believes. Nothing here is
/// derived: no fare arithmetic, no VAT, no availability filtering.
///
/// Scope this per booking attempt (a `ChangeNotifierProvider` above the booking
/// screen) rather than app-wide, and call [reset] when the user abandons the
/// flow.
class BookingSessionProvider extends ChangeNotifier {
  BookingSessionProvider({BookingApiV2? api}) : _api = api ?? BookingApiV2();

  final BookingApiV2 _api;

  // ── State ────────────────────────────────────────────────────────────────

  BookingServiceType? _serviceType;
  BookingSession? _session;
  AvailableVehiclesResponse? _vehicles;
  CheckoutDetails? _checkout;
  ConfirmBookingResult? _confirmation;
  SessionBusy _busy = SessionBusy.idle;
  String? _errorMessage;

  /// The product being booked, set when the session is initialised.
  BookingServiceType? get serviceType => _serviceType;

  /// The server-held draft. `null` until step 1 succeeds.
  BookingSession? get session => _session;

  /// Route resolved by the backend (cities, zones, airport, pickup instant).
  SessionRoute? get route => _session?.route;

  /// Vehicles for the current route, priced server-side.
  AvailableVehiclesResponse? get vehicles => _vehicles;

  /// Server-authoritative price breakdown for the review screen.
  CheckoutDetails? get checkout => _checkout;
  CheckoutPricing? get pricing => _checkout?.pricing;

  /// Result of the last [confirm] call.
  ConfirmBookingResult? get confirmation => _confirmation;

  SessionBusy get busy => _busy;
  bool get isBusy => _busy != SessionBusy.idle;

  /// Last failure message, suitable for display.
  String? get errorMessage => _errorMessage;

  /// Whether a draft exists on the server.
  bool get hasSession => _session != null;

  /// How far the backend says the draft has progressed.
  int get step => _session?.step ?? 0;

  /// The vehicle currently attached to the draft.
  SelectedVehicle? get selectedVehicle => _session?.selectedVehicle;

  /// Notes attached in step 2.
  String? get rideNotes => _session?.rideNotes;

  /// Total the user will be charged, per the backend.
  double get totalAmount => _checkout?.pricing.totalAmount ?? 0;

  /// Whether the booking completes without a payment step.
  bool get isZeroCheckout => _checkout?.pricing.isZeroCheckout ?? false;

  /// The coupon currently applied, if any.
  AppliedCoupon? get appliedCoupon => _checkout?.pricing.discounts.coupon;

  // ── Step 1: initiation ───────────────────────────────────────────────────

  /// Start an airport-transfer draft.
  ///
  /// [customerLat]/[customerLng]/[customerAddress] are the non-airport end of
  /// the trip, whichever direction is being booked.
  Future<bool> startAirportSession({
    required BookingServiceType serviceType,
    required String airportId,
    required String terminalId,
    required double customerLat,
    required double customerLng,
    required String customerAddress,
    required DateTime pickupDateTime,
    String? flightNumber,
  }) {
    _serviceType = serviceType;
    return _runSession(
      SessionBusy.initialising,
      () => _api.initAirportTransferSession(
        serviceType: serviceType,
        airportId: airportId,
        terminalId: terminalId,
        customerLat: customerLat,
        customerLng: customerLng,
        customerAddress: customerAddress,
        pickupDateTime: pickupDateTime,
        flightNumber: flightNumber,
      ),
    );
  }

  /// Start a private-transfer draft. Both endpoints must be inside active zones.
  Future<bool> startPrivateTransferSession({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double dropOffLat,
    required double dropOffLng,
    required String dropOffAddress,
    required DateTime pickupDateTime,
  }) {
    _serviceType = BookingServiceType.privateTransfer;
    return _runSession(
      SessionBusy.initialising,
      () => _api.initPrivateTransferSession(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        pickupAddress: pickupAddress,
        dropOffLat: dropOffLat,
        dropOffLng: dropOffLng,
        dropOffAddress: dropOffAddress,
        pickupDateTime: pickupDateTime,
      ),
    );
  }

  /// Start a chauffeur draft for [hours] of hire, either hourly or as one of
  /// the fixed packages.
  Future<bool> startChauffeurSession({
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required int hours,
    required DateTime pickupDateTime,
    ChauffeurType chauffeurType = ChauffeurType.hourly,
  }) {
    _serviceType = BookingServiceType.chauffeur;
    return _runSession(
      SessionBusy.initialising,
      () => _api.initChauffeurSession(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        pickupAddress: pickupAddress,
        hours: hours,
        pickupDateTime: pickupDateTime,
        chauffeurType: chauffeurType,
      ),
    );
  }

  // ── Step 2: vehicle ──────────────────────────────────────────────────────

  /// Load vehicles for the current draft, optionally filtered.
  ///
  /// Passing `null` for a filter clears it.
  Future<bool> loadVehicles({String? categoryId, String? brandId}) async {
    _setBusy(SessionBusy.loadingVehicles);

    final result = await _api.getAvailableVehicles(
      categoryId: categoryId,
      brandId: brandId,
    );

    if (result.hasData) {
      _vehicles = result.data;
      _finish();
      return true;
    }

    _fail(result.message);
    return false;
  }

  /// Attach [vehicleId], optional [rideNotes] and an optional recording at
  /// [voiceNotePath] to the draft.
  Future<bool> selectVehicle({
    required String vehicleId,
    String? rideNotes,
    String? voiceNotePath,
  }) {
    return _runSession(
      SessionBusy.savingVehicle,
      () => _api.selectVehicle(
        vehicleId: vehicleId,
        rideNotes: rideNotes,
        voiceNotePath: voiceNotePath,
      ),
    );
  }

  // ── Step 3: passenger ────────────────────────────────────────────────────

  /// Save passenger details onto the draft.
  Future<bool> savePassengerDetails({
    required int passengersCount,
    required String passengerNames,
    required String passengerPhone,
  }) {
    return _runSession(
      SessionBusy.savingPassenger,
      () => _api.savePassengerDetails(
        passengersCount: passengersCount,
        passengerNames: passengerNames,
        passengerPhone: passengerPhone,
      ),
    );
  }

  // ── Step 4: checkout ─────────────────────────────────────────────────────

  /// Fetch the price breakdown for the review screen.
  Future<bool> loadCheckout() =>
      _runCheckout(SessionBusy.loadingCheckout, _api.getCheckout);

  /// Apply a coupon; the whole checkout is recalculated server-side.
  Future<bool> applyCoupon(String code) =>
      _runCheckout(SessionBusy.applyingCoupon, () => _api.applyCoupon(code));

  /// Remove the applied coupon.
  Future<bool> removeCoupon() =>
      _runCheckout(SessionBusy.applyingCoupon, _api.removeCoupon);

  /// Confirm the draft, creating the booking before any payment is attempted.
  ///
  /// Returns the result so the caller can branch on
  /// [ConfirmBookingResult.paymentRequired]; `null` means the call failed and
  /// [errorMessage] explains why.
  Future<ConfirmBookingResult?> confirm() async {
    _setBusy(SessionBusy.confirming);

    final result = await _api.confirmBooking();
    final confirmation = result.data;

    if (!result.success || confirmation == null) {
      _fail(result.message);
      return null;
    }

    // A paid confirmation without usable gateway parameters cannot proceed —
    // treat it as a failure rather than opening a misconfigured SDK screen.
    if (confirmation.paymentRequired &&
        !(confirmation.paytabsConfig?.isUsable ?? false)) {
      _fail('Payment could not be started. Please try again.');
      return null;
    }

    _confirmation = confirmation;
    _finish();
    return confirmation;
  }

  /// Documented polling cadence for a payment still with the gateway.
  static const Duration _verifyInterval = Duration(seconds: 3);

  /// Roughly a minute of polling before the decision is handed back to the
  /// user. 3-D Secure and bank clearance are well inside that.
  static const int _verifyMaxAttempts = 20;

  /// Read the payment status once.
  ///
  /// The server decides whether the charge captured; a successful SDK callback
  /// alone is not treated as proof.
  Future<PaymentVerificationResult?> verifyPayment() async {
    final bookingNumber = _confirmation?.bookingNumber;
    if (bookingNumber == null || bookingNumber.isEmpty) {
      _fail('Missing booking reference. Please contact support.');
      return null;
    }

    _setBusy(SessionBusy.verifyingPayment);

    final result = await _api.verifyPayment(bookingNumber: bookingNumber);

    if (!result.hasData) {
      _fail(result.message);
      return null;
    }

    _finish();
    return result.data;
  }

  /// Poll the read-only verify endpoint until the gateway settles.
  ///
  /// `initiated` and `pending` mean the payment is still with the gateway, so
  /// it is re-read every [_verifyInterval] until it reports captured or failed.
  ///
  /// Returns the last result seen. A still-pending one means it had not settled
  /// within [_verifyMaxAttempts] — the booking stays `pending_payment` and the
  /// caller should say so rather than claim either outcome. `null` means a
  /// request failed outright, with [errorMessage] explaining why; polling stops
  /// there rather than hiding a real error behind a spinner for a minute.
  Future<PaymentVerificationResult?> awaitPaymentSettled() async {
    PaymentVerificationResult? last;

    for (var attempt = 1; attempt <= _verifyMaxAttempts; attempt++) {
      final result = await verifyPayment();
      if (result == null) return null;

      last = result;

      if (!result.isPending) return result;
      if (attempt < _verifyMaxAttempts) await Future.delayed(_verifyInterval);
    }

    return last;
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  /// Clear the local mirror.
  ///
  /// Does not delete the server draft — that expires on its own TTL, and is
  /// overwritten by the next session initiation for this user.
  void reset() {
    _serviceType = null;
    _session = null;
    _vehicles = null;
    _checkout = null;
    _confirmation = null;
    _busy = SessionBusy.idle;
    _errorMessage = null;
    notifyListeners();
  }

  /// Dismiss the current error without touching the rest of the state.
  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Internals ────────────────────────────────────────────────────────────

  /// Run a call that returns an updated draft and adopt it as local state.
  Future<bool> _runSession(
    SessionBusy busy,
    Future<ApiResult<BookingSession>> Function() call,
  ) async {
    _setBusy(busy);

    final result = await call();
    if (result.hasData) {
      _session = result.data;
      _finish();
      return true;
    }

    _fail(result.message);
    return false;
  }

  /// Run a call that returns a checkout view and adopt it as local state.
  Future<bool> _runCheckout(
    SessionBusy busy,
    Future<ApiResult<CheckoutDetails>> Function() call,
  ) async {
    _setBusy(busy);

    final result = await call();
    if (result.hasData) {
      _checkout = result.data;
      // Coupon and checkout responses carry the full summary, so keep the draft
      // mirror in step with them.
      _session = result.data!.summary;
      _finish();
      return true;
    }

    _fail(result.message);
    return false;
  }

  void _setBusy(SessionBusy busy) {
    _busy = busy;
    _errorMessage = null;
    notifyListeners();
  }

  void _finish() {
    _busy = SessionBusy.idle;
    notifyListeners();
  }

  void _fail(String? message) {
    _busy = SessionBusy.idle;
    _errorMessage = message ?? 'Something went wrong. Please try again.';
    notifyListeners();
  }
}
