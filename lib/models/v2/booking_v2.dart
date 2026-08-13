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
      'canceled' => cancelled,
      'in_trip' || 'ontrip' || 'on_trip' || 'started' => tripStarted,
      'en_route' || 'enroute' => driverEnRoute,
      'arrived' => driverArrived,
      'assigned' => driverAssigned,
      'awaiting_payment' || 'paymentpending' => pendingPayment,
      _ => unknown,
    };
  }

  /// Which tab of the bookings screen this belongs to. Mirrors the `status`
  /// query parameter accepted by `/bookings/my-bookings`.
  String get listBucket => switch (this) {
    confirmed || driverAssigned => 'upcoming',
    driverEnRoute || driverArrived || tripStarted => 'ongoing',
    completed => 'completed',
    cancelled => 'cancelled',
    // A draft awaiting payment is not shown in any customer-facing tab.
    pendingPayment || unknown => 'all',
  };

  /// Whether the ride is underway, which is what gates live driver tracking.
  bool get isLive =>
      this == driverEnRoute || this == driverArrived || this == tripStarted;

  bool get isCancellable =>
      this == confirmed || this == driverAssigned || this == driverEnRoute;
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
    this.phone,
    this.rating,
    this.avatar,
  });

  final String id;
  final String? name;
  final String? phone;
  final double? rating;
  final String? avatar;

  factory DriverV2.fromJson(Map<String, dynamic> json) {
    return DriverV2(
      id: pickId(json, const ['_id', 'id', 'driverId']) ?? '',
      name: pickString(json, const ['name', 'driverName', 'fullName']),
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
        'refundReference',
        'transactionRef',
      ]),
      refundedAt: pickDateTime(json, const ['refundedAt', 'processedAt']),
    );
  }
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
    this.pricing,
    this.driver,
    this.fleet,
    this.payment,
    this.refund,
    this.timeline = const [],
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
  final CheckoutPricing? pricing;
  final DriverV2? driver;
  final FleetV2? fleet;
  final PaymentInfoV2? payment;
  final RefundInfoV2? refund;

  /// Empty on list payloads; populated on detail.
  final List<BookingTimelineStep> timeline;

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
      pricing: pricingJson.isEmpty
          ? null
          : CheckoutPricing.fromJson(pricingJson),
      driver: driverJson.isEmpty ? null : DriverV2.fromJson(driverJson),
      fleet: fleetJson.isEmpty ? null : FleetV2.fromJson(fleetJson),
      payment: paymentJson.isEmpty ? null : PaymentInfoV2.fromJson(paymentJson),
      refund: refundJson.isEmpty ? null : RefundInfoV2.fromJson(refundJson),
      timeline: pickMapList(json, const [
        'timeline',
      ]).map(BookingTimelineStep.fromJson).toList(),
      createdAt: pickDateTime(json, const ['createdAt']),
      updatedAt: pickDateTime(json, const ['updatedAt']),
    );
  }

  BookingServiceType? get resolvedServiceType =>
      BookingServiceType.fromResponse(serviceType, transferSubType);

  /// Pickup instant, for date/time display.
  DateTime? get pickupDateTime => route?.pickupDateTime;

  /// Pickup address, falling back to the airport name on arrivals where the
  /// pickup point is a terminal rather than a street address.
  String? get pickupAddress =>
      route?.pickupLocation?.address ?? route?.airport?.name;

  /// Drop-off address. Null for chauffeur hire, which has no destination.
  String? get dropOffAddress => route?.dropOffLocation?.address;

  double? get pickupLat => route?.pickupLocation?.lat;
  double? get pickupLng => route?.pickupLocation?.lng;
  double? get dropOffLat => route?.dropOffLocation?.lat;
  double? get dropOffLng => route?.dropOffLocation?.lng;

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

  /// Whether a refund has been issued or is in flight.
  bool get hasRefund => refund != null;

  /// Total charged, in the checkout currency.
  double get totalAmount => pricing?.totalAmount ?? 0;

  String get currency => pricing?.currency ?? 'SAR';
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
    final meta = pickMap(json, const ['meta', 'pagination']);
    return BookingListPage(
      bookings: pickMapList(json, const [
        'bookings',
        'data',
        'items',
      ]).map(BookingV2.fromJson).toList(),
      page: pickInt(meta, const ['page']) ?? 1,
      limit: pickInt(meta, const ['limit']) ?? 10,
      total: pickInt(meta, const ['total']) ?? 0,
      totalPages: pickInt(meta, const ['totalPages']) ?? 1,
    );
  }

  bool get hasMore => page < totalPages;
}
