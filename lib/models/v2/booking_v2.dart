import 'package:premium_force_main/models/v2/booking_service_type.dart';
import 'package:premium_force_main/models/v2/checkout_models.dart';
import 'package:premium_force_main/models/v2/session_models.dart';
import 'package:premium_force_main/utils/json_utils.dart';

/// Confirmed-booking models for `GET /bookings/my-bookings` and
/// `GET /bookings/:id`.
///
/// The list and detail payloads share a shape — detail simply adds
/// [BookingV2.passengerDetails], [BookingV2.payment], [BookingV2.refund] and the
/// [BookingV2.timeline] — so one model covers both.

/// Lifecycle of a v2 booking.
///
/// Replaces the untyped, case-insensitive status strings of the old flow.
enum BookingStatusV2 {
  pendingPayment('pending_payment'),
  confirmed('confirmed'),
  driverAssigned('driver_assigned'),
  driverEnRoute('driver_en_route'),
  driverArrived('driver_arrived'),
  tripStarted('trip_started'),
  completed('completed'),
  cancelled('cancelled'),
  unknown('unknown');

  const BookingStatusV2(this.wireValue);

  /// The exact string the API uses.
  final String wireValue;

  static BookingStatusV2 fromWire(String? value) {
    final normalised = value?.trim().toLowerCase().replaceAll('-', '_');
    if (normalised == null || normalised.isEmpty) return unknown;
    for (final status in values) {
      if (status.wireValue == normalised) return status;
    }
    // Tolerate spellings the backend may use interchangeably.
    return switch (normalised) {
      'canceled' || 'cancelled' => cancelled,
      'in_trip' ||
      'ontrip' ||
      'on_trip' ||
      'started' ||
      'trip_started' => tripStarted,
      'driver_en_route' || 'enroute' || 'en_route' => driverEnRoute,
      'arrived' || 'driver_arrived' => driverArrived,
      'assigned' || 'driver_assigned' => driverAssigned,
      'awaiting_payment' || 'paymentpending' => pendingPayment,
      _ => unknown,
    };
  }

  /// Whether the ride is underway.
  bool get isLive =>
      this == driverEnRoute || this == driverArrived || this == tripStarted;

  /// Whether the driver's live position is being published for this booking,
  /// and so whether tracking is worth offering at all.
  ///
  /// Mirrors the driver app's own sharing window, which opens the moment the
  /// driver sets off for the pickup (`driver_en_route`) and closes when the
  /// ride ends. Offering it any earlier would open a map with no car on it;
  /// offering it only from `trip_started`, as this used to, hid the half of the
  /// journey the customer actually waits through. Every route into the tracking
  /// screen is gated on this — the home card, and the button on the booking's
  /// details.
  bool get isTrackable => isLive;

  /// Whether a driver has been put on the ride.
  ///
  /// True from assignment onwards and through the ride itself, which is what
  /// decides whether the card names a chauffeur or says none is assigned yet.
  bool get hasDriver => this == driverAssigned || isLive;

  /// Whether the customer may still cancel.
  ///
  /// Mirrors the endpoint's own guard: allowed up to and including
  /// `driver_assigned`, and rejected with a 400 once the ride is under way
  /// (`driver_en_route` onwards) or already finished.
  bool get isCancellable =>
      this == pendingPayment || this == confirmed || this == driverAssigned;

  /// Whether the booking is over, either way — the two statuses behind the
  /// Completed and Cancelled tabs.
  ///
  /// What it gates is contact with the driver: there is no longer a ride to
  /// call about, so the details screen stops showing the driver's number and
  /// the call button once this is true. The driver is still named and rated
  /// from there; only the phone goes.
  bool get isConcluded => this == completed || this == cancelled;
}

/// The tabs of the bookings screen.
///
/// Each is its own server-side query rather than a slice of one big response,
/// so the bucketing rules live with the backend. [wireValue] is what
/// `GET /bookings/my-bookings` expects for `status` — the English name, always
/// lowercase, which is the only casing the endpoint validates against. The
/// localised tab label is never sent.
enum BookingTab {
  upcoming('upcoming'),
  ongoing('ongoing'),
  completed('completed'),
  cancelled('cancelled');

  const BookingTab(this.wireValue);

  final String wireValue;

  /// Sent when no tab filter applies — the home screen's recent list, which
  /// spans every status.
  static const String allWireValue = 'all';
}

/// A step in the vertical progress stepper rendered on the details screen.
class BookingTimelineStep {
  const BookingTimelineStep({
    required this.key,
    required this.label,
    this.labelAr,
    this.isCompleted = false,
    this.isCurrent = false,
    this.isCancelled = false,
    this.timestamp,
  });

  final String key;
  final String label;
  final String? labelAr;
  final bool isCompleted;
  final bool isCurrent;
  final bool isCancelled;
  final DateTime? timestamp;

  factory BookingTimelineStep.fromJson(Map<String, dynamic> json) {
    return BookingTimelineStep(
      key: pickString(json, const ['key']) ?? '',
      label: pickString(json, const ['label']) ?? '',
      labelAr: pickString(json, const ['labelAr']),
      isCompleted: pickBool(json, const ['isCompleted']) ?? false,
      isCurrent: pickBool(json, const ['isCurrent']) ?? false,
      isCancelled: pickBool(json, const ['isCancelled']) ?? false,
      timestamp: pickDateTime(json, const ['timestamp']),
    );
  }

  String displayLabel(bool isArabic) => isArabic
      ? (labelAr?.trim().isNotEmpty == true ? labelAr! : label)
      : label;
}

/// The assigned driver, once one exists.
class DriverV2 {
  const DriverV2({
    required this.id,
    this.name,
    this.countryCode,
    this.phone,
    this.rating,
    this.avatar,
  });

  final String id;
  final String? name;

  /// Dialling prefix for [phone], as the payload sends it — `"+91"`.
  ///
  /// Kept apart from the number because that is how the backend stores it, and
  /// because either half can be absent: an older booking carries no prefix at
  /// all. [fullPhone] is what anything user-facing should read.
  final String? countryCode;

  /// The subscriber number, without its prefix.
  final String? phone;
  final double? rating;
  final String? avatar;

  /// The number to show and to dial — `"+919847801552"`.
  ///
  /// Null when there is no number at all. The prefix is joined on only when it
  /// adds something: a payload that already sends a fully qualified number, or
  /// one repeating the prefix inside [phone], must not come out as `+91+91…`
  /// or `+9191…`, either of which is a number that does not ring.
  String? get fullPhone {
    final number = phone?.trim();
    if (number == null || number.isEmpty) return null;

    final code = countryCode?.trim();
    if (code == null || code.isEmpty) return number;
    if (number.startsWith('+')) return number;

    final digits = code.startsWith('+') ? code.substring(1) : code;
    if (digits.isEmpty) return number;
    if (number.startsWith(digits)) return '+$number';

    return '+$digits$number';
  }

  factory DriverV2.fromJson(Map<String, dynamic> json) {
    return DriverV2(
      id: pickId(json, const ['_id', 'id', 'driverId']) ?? '',
      name: pickString(json, const ['name', 'driverName', 'fullName']),
      countryCode: pickString(json, const [
        'countryCode',
        'dialCode',
        'phoneCode',
      ]),
      phone: pickString(json, const ['phone', 'phoneNumber', 'mobile']),
      rating: pickDouble(json, const ['rating', 'rate']),
      avatar: pickString(json, const ['avatar', 'image', 'profileImage']),
    );
  }
}

/// The assigned fleet vehicle (the physical car, distinct from the vehicle
/// *class* the customer booked).
class FleetV2 {
  const FleetV2({required this.id, this.licensePlate});

  final String id;
  final String? licensePlate;

  factory FleetV2.fromJson(Map<String, dynamic> json) {
    return FleetV2(
      id: pickId(json, const ['_id', 'id', 'fleetId']) ?? '',
      licensePlate: pickString(json, const [
        'licensePlate',
        'plateNumber',
        'plate',
      ]),
    );
  }
}

/// The payment transaction backing the booking.
class PaymentInfoV2 {
  const PaymentInfoV2({
    this.id,
    this.gateway,
    this.status,
    this.transactionRef,
    this.amount,
    this.currency,
  });

  final String? id;
  final String? gateway;

  /// e.g. `initiated`, `captured`, `failed`, `refunded`.
  final String? status;

  final String? transactionRef;
  final double? amount;
  final String? currency;

  factory PaymentInfoV2.fromJson(Map<String, dynamic> json) {
    return PaymentInfoV2(
      id: pickId(json, const ['_id', 'id']),
      gateway: pickString(json, const ['gateway', 'provider']),
      status: pickString(json, const ['status'])?.toLowerCase(),
      transactionRef: pickString(json, const [
        'transactionRef',
        'transactionReference',
      ]),
      amount: pickDouble(json, const ['amount']),
      currency: pickString(json, const ['currency']),
    );
  }

  bool get isCaptured => status == 'captured' || status == 'paid';
}

/// Refund details, present once a cancellation has triggered one.
class RefundInfoV2 {
  const RefundInfoV2({
    this.status,
    this.amount,
    this.currency,
    this.reference,
    this.refundedAt,
  });

  final String? status;
  final double? amount;
  final String? currency;
  final String? reference;
  final DateTime? refundedAt;

  factory RefundInfoV2.fromJson(Map<String, dynamic> json) {
    return RefundInfoV2(
      status: pickString(json, const ['status'])?.toLowerCase(),
      amount: pickDouble(json, const ['amount']),
      currency: pickString(json, const ['currency']),
      reference: pickString(json, const [
        'reference',
        'refundNumber',
        'refundReference',
        'transactionRef',
      ]),
      refundedAt: pickDateTime(json, const ['refundedAt', 'processedAt']),
    );
  }
}

/// Acknowledgement returned by `POST /bookings/:id/cancel`.
///
/// The endpoint replies with the outcome, not the booking — the cancelled
/// booking itself has to be re-read — so this is deliberately a separate type
/// rather than a sparsely-populated [BookingV2].
class BookingCancellation {
  const BookingCancellation({
    required this.status,
    this.bookingNumber,
    this.refundStatus,
    this.refundNumber,
    this.refundAmount,
  });

  final BookingStatusV2 status;
  final String? bookingNumber;

  /// e.g. `completed`; absent on a zero-checkout ride, which never touches the
  /// gateway.
  final String? refundStatus;

  final String? refundNumber;
  final double? refundAmount;

  factory BookingCancellation.fromJson(Map<String, dynamic> json) {
    return BookingCancellation(
      status: BookingStatusV2.fromWire(
        pickString(json, const ['bookingStatus', 'status']),
      ),
      bookingNumber: pickString(json, const ['bookingNumber']),
      refundStatus: pickString(json, const ['refundStatus'])?.toLowerCase(),
      refundNumber: pickString(json, const ['refundNumber', 'refundReference']),
      refundAmount: pickDouble(json, const ['refundAmount']),
    );
  }

  /// Whether a gateway refund was actually raised, as opposed to a free ride
  /// that simply cancelled.
  bool get hasRefund => (refundAmount ?? 0) > 0 || refundNumber != null;
}

/// A confirmed booking.
class BookingV2 {
  const BookingV2({
    required this.id,
    required this.bookingNumber,
    required this.status,
    this.serviceType,
    this.transferSubType,
    this.route,
    this.vehicle,
    this.passengerDetails,
    this.rideNotes,
    this.voiceNote,
    this.pricing,
    this.driver,
    this.fleet,
    this.payment,
    this.refund,
    this.extraCharges,
    this.cancellationNote,
    this.timeline = const [],
    this.invoiceUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String bookingNumber;
  final BookingStatusV2 status;
  final String? serviceType;
  final String? transferSubType;

  /// Reuses [SessionRoute] — the booking route payload is the same shape as the
  /// session's, with cities optionally populated as sub-documents.
  final SessionRoute? route;

  final SelectedVehicle? vehicle;
  final PassengerDetails? passengerDetails;
  final String? rideNotes;

  /// S3 URL of the recording the customer attached with their ride notes.
  ///
  /// Uploaded during vehicle selection and carried through to the booking, so
  /// the detail payload echoes it back alongside [rideNotes].
  final String? voiceNote;
  final CheckoutPricing? pricing;
  final DriverV2? driver;
  final FleetV2? fleet;
  final PaymentInfoV2? payment;
  final RefundInfoV2? refund;

  /// Extra charges applied after trip completion (waiting time, parking, etc).
  final ExtraCharges? extraCharges;

  /// Why the booking was cancelled, as it was recorded against the booking.
  ///
  /// Present only on cancelled bookings, and only once somebody has written
  /// one. The backend has spelled this key more than one way and nests it
  /// under `cancellation` on some responses, so every placement seen so far is
  /// read.
  final String? cancellationNote;

  /// Empty on list payloads; populated on detail.
  final List<BookingTimelineStep> timeline;

  /// Path to the ZATCA-compliant VAT invoice PDF, relative to the API root
  /// (`/api/v2/bookings/:id/invoice`).
  ///
  /// The backend attaches it only once the booking is paid for or confirmed and
  /// leaves it null while payment is pending or has failed, so its presence is
  /// what decides whether an invoice can be opened.
  final String? invoiceUrl;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory BookingV2.fromJson(Map<String, dynamic> json) {
    final vehicleJson = pickMap(json, const ['vehicle']);
    final driverJson = pickMap(json, const ['driver']);
    final fleetJson = pickMap(json, const ['fleet']);
    final paymentJson = pickMap(json, const ['payment']);
    final refundJson = pickMap(json, const ['refund']);
    final pricingJson = pickMap(json, const ['pricing']);
    final passengerJson = pickMap(json, const ['passengerDetails']);
    final extraChargesJson = pickMap(json, const ['extraCharges']);

    return BookingV2(
      id: pickId(json, const ['_id', 'id', 'bookingId']) ?? '',
      bookingNumber: pickString(json, const ['bookingNumber']) ?? '',
      status: BookingStatusV2.fromWire(
        pickString(json, const ['bookingStatus', 'status']),
      ),
      serviceType: pickString(json, const ['serviceType']),
      transferSubType: pickString(json, const ['transferSubType']),
      route: json['route'] == null
          ? null
          : SessionRoute.fromJson(pickMap(json, const ['route'])),
      vehicle: vehicleJson.isEmpty
          ? null
          : SelectedVehicle.fromJson(vehicleJson),
      passengerDetails: passengerJson.isEmpty
          ? null
          : PassengerDetails.fromJson(passengerJson),
      rideNotes: pickString(json, const ['rideNotes']),
      voiceNote: pickString(json, const [
        'voiceNote',
        'voiceNoteUrl',
        'specialRequestAudio',
      ]),
      pricing: pricingJson.isEmpty
          ? null
          : CheckoutPricing.fromJson(pricingJson),
      driver: driverJson.isEmpty ? null : DriverV2.fromJson(driverJson),
      fleet: fleetJson.isEmpty ? null : FleetV2.fromJson(fleetJson),
      payment: paymentJson.isEmpty ? null : PaymentInfoV2.fromJson(paymentJson),
      refund: refundJson.isEmpty ? null : RefundInfoV2.fromJson(refundJson),
      extraCharges: extraChargesJson.isEmpty
          ? null
          : ExtraCharges.fromJson(extraChargesJson),
      cancellationNote: _cancellationNoteOf(json),
      timeline: pickMapList(json, const [
        'timeline',
      ]).map(BookingTimelineStep.fromJson).toList(),
      invoiceUrl: pickString(json, const ['invoiceUrl']),
      createdAt: pickDateTime(json, const ['createdAt']),
      updatedAt: pickDateTime(json, const ['updatedAt']),
    );
  }

  BookingServiceType? get resolvedServiceType =>
      BookingServiceType.fromResponse(serviceType, transferSubType);

  /// Pickup instant, for date/time display.
  DateTime? get pickupDateTime => route?.pickupDateTime;

  /// How close to the pickup the customer may still cancel.
  static const Duration cancellationCutoff = Duration(hours: 4);

  /// Whether the customer may still cancel this booking.
  ///
  /// Two things have to hold, and the status is only the first of them:
  /// [BookingStatusV2.isCancellable] says the ride has not started, and
  /// [isWithinCancellationCutoff] says the pickup is still far enough off. A
  /// booking four hours out is close enough that a car is being readied for
  /// it, so the button comes down even though the status would still allow it.
  ///
  /// This is what the cancel button is gated on; the status alone is not.
  bool get isCancellable => status.isCancellable && !isWithinCancellationCutoff;

  /// Whether the pickup is now [cancellationCutoff] away or nearer.
  ///
  /// The boundary itself counts as closed: a pickup exactly four hours off is
  /// inside the rule, not the last minute outside it.
  ///
  /// False when the payload names no pickup at all: the button is left to the
  /// status rule rather than taken away over a date the app never had.
  bool get isWithinCancellationCutoff {
    final remaining = untilCancellationCloses;
    return remaining != null && remaining <= Duration.zero;
  }

  /// How long is left before cancelling closes, or null when the payload names
  /// no pickup. Negative once the window has closed.
  ///
  /// Measured against `pickupUTC` — the backend's authoritative instant —
  /// rather than the wall clock the card prints, because only the instant is
  /// comparable to *now* from a phone in another timezone: a Riyadh pickup
  /// reading 5:15 PM on the card is four hours away at a different moment for
  /// a customer in Karachi than for one in Riyadh. The wall clock stands in
  /// only for a payload that carries no instant at all, where reading it as
  /// device-local is the closest thing to the pickup on the card.
  Duration? get untilCancellationCloses {
    final pickup = pickupDateTime ?? route?.pickupWallClock;
    if (pickup == null) return null;
    return pickup.subtract(cancellationCutoff).difference(DateTime.now());
  }

  /// Pickup address, falling back to the airport name on arrivals where the
  /// pickup point is a terminal rather than a street address.
  String? get pickupAddress =>
      route?.pickupLocation?.address ?? route?.airport?.name;

  /// Drop-off address. Null for chauffeur hire, which has no destination.
  String? get dropOffAddress => route?.dropOffLocation?.address;

  /// Coordinates of the two ends of the journey.
  ///
  /// Each falls back to the airport's own position on the leg where the airport
  /// *is* that end — the pickup on an arrival, the drop-off on a departure.
  /// The payload gives no `pickupLocation` for a terminal, so without this the
  /// tracking map had no coordinate to pin or route to on airport bookings and
  /// drew the driver alone on an empty map. [pickupAddress] has always fallen
  /// back the same way; only the coordinates were missed.
  ///
  /// Still null when the airport record itself carries no position, which some
  /// do not — callers must handle that rather than assume a coordinate exists.
  double? get pickupLat =>
      route?.pickupLocation?.lat ?? (isAirportArrival ? route?.airport?.lat : null);
  double? get pickupLng =>
      route?.pickupLocation?.lng ?? (isAirportArrival ? route?.airport?.lng : null);
  double? get dropOffLat =>
      route?.dropOffLocation?.lat ??
      (isAirportDeparture ? route?.airport?.lat : null);
  double? get dropOffLng =>
      route?.dropOffLocation?.lng ??
      (isAirportDeparture ? route?.airport?.lng : null);

  bool get isAirportArrival =>
      resolvedServiceType == BookingServiceType.airportArrival;
  bool get isAirportDeparture =>
      resolvedServiceType == BookingServiceType.airportDeparture;

  /// Whether this is hourly chauffeur hire.
  bool get isChauffeur =>
      resolvedServiceType == BookingServiceType.chauffeur ||
      (route?.durationHours ?? 0) > 0;

  /// Vehicle label, e.g. `"S450 2023"`.
  String get vehicleLabel => [
    vehicle?.name,
    vehicle?.model,
  ].where((p) => p?.trim().isNotEmpty == true).join(' ').trim();

  int get passengersCount => passengerDetails?.passengersCount ?? 1;

  /// Whether a recording was attached to the ride notes.
  bool get hasVoiceNote => voiceNote?.trim().isNotEmpty ?? false;

  /// Whether a cancellation note was recorded, which is what decides if the
  /// card and the details screen show one.
  bool get hasCancellationNote =>
      cancellationNote?.trim().isNotEmpty ?? false;

  /// Whether a refund has been issued or is in flight.
  bool get hasRefund => refund != null;

  /// Whether a VAT invoice can be opened for this booking.
  bool get hasInvoice => (invoiceUrl?.trim().isNotEmpty ?? false);

  /// Whether the ride is finished, which is what gates rating the driver.
  bool get isCompleted => status == BookingStatusV2.completed;

  /// Total charged, in the checkout currency.
  double get totalAmount => pricing?.totalAmount ?? 0;

  String get currency => pricing?.currency ?? 'SAR';
}

/// Read the cancellation note off a booking payload.
///
/// The note has arrived under more than one name, and on some responses it is
/// nested inside a `cancellation` object rather than sitting on the booking
/// itself, so every placement is tried before giving up. A blank string counts
/// as no note — `pickString` already treats it as absent — which keeps an
/// empty note from rendering an empty banner.
String? _cancellationNoteOf(Map<String, dynamic> json) {
  final nested = pickMap(json, const [
    'cancellation',
    'cancellationDetails',
    'cancelDetails',
  ]);

  return pickString(json, const [
        'cancellationNote',
        'cancelledNote',
        'cancelNote',
        'cancellationReason',
        'cancelledReason',
        'cancelReason',
        'cancellationRemarks',
      ]) ??
      pickString(nested, const [
        'note',
        'notes',
        'reason',
        'remarks',
        'message',
        'cancellationNote',
        'cancellationReason',
      ]);
}

/// Pagination envelope for `GET /bookings/my-bookings`.
class BookingListPage {
  const BookingListPage({
    required this.bookings,
    this.page = 1,
    this.limit = 10,
    this.total = 0,
    this.totalPages = 1,
  });

  final List<BookingV2> bookings;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory BookingListPage.fromJson(Map<String, dynamic> json) {
    // Pagination arrives either nested under `meta`/`pagination` or flattened
    // onto the payload. Reading the wrong one would silently pin every tab to
    // a single page, so both are tried.
    final meta = pickMap(json, const ['meta', 'pagination']);
    final source = meta.isNotEmpty ? meta : json;

    final page = pickInt(source, const ['page', 'currentPage']) ?? 1;
    final limit = pickInt(source, const ['limit', 'pageSize', 'perPage']) ?? 10;
    final total =
        pickInt(source, const ['total', 'totalCount', 'totalItems']) ?? 0;

    return BookingListPage(
      bookings: pickMapList(json, const [
        'bookings',
        'data',
        'items',
      ]).map(BookingV2.fromJson).toList(),
      page: page,
      limit: limit,
      total: total,
      // Derived when the API reports only a total, so paging still advances.
      totalPages:
          pickInt(source, const ['totalPages', 'pages']) ??
          (total > 0 && limit > 0 ? (total + limit - 1) ~/ limit : 1),
    );
  }

  bool get hasMore => page < totalPages;
}
