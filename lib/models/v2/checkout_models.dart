import 'package:premium_force_main/models/v2/session_models.dart';
import 'package:premium_force_main/utils/json_utils.dart';

/// Checkout models — the server-authoritative price breakdown and the result of
/// confirming a session.
///
/// Nothing here is computed on-device. [CheckoutPricing] is rendered as given;
/// the client never derives VAT, discount, or the total, and never sends an
/// amount of its own to PayTabs.

/// A coupon applied to the session.
class AppliedCoupon {
  const AppliedCoupon({required this.code, required this.amount});

  final String code;

  /// Absolute discount in the checkout currency, not a percentage.
  final double amount;

  factory AppliedCoupon.fromJson(Map<String, dynamic> json) {
    return AppliedCoupon(
      code: pickString(json, const ['code', 'couponCode']) ?? '',
      amount: pickDouble(json, const ['amount', 'discountAmount']) ?? 0,
    );
  }
}

/// The discount block: an account-level discount plus an optional coupon.
class PricingDiscounts {
  const PricingDiscounts({
    this.specialIdDiscount = 0,
    this.coupon,
    this.totalDiscount = 0,
  });

  /// Discount from the user's approved special/corporate id, if any.
  final double specialIdDiscount;

  /// `null` when no coupon is applied.
  final AppliedCoupon? coupon;

  final double totalDiscount;

  factory PricingDiscounts.fromJson(Map<String, dynamic> json) {
    // `coupon` is explicitly null when none is applied, and may be a stub with
    // a null code on booking-detail payloads.
    final couponJson = pickMap(json, const ['coupon']);
    final couponCode = pickString(couponJson, const ['code', 'couponCode']);

    return PricingDiscounts(
      specialIdDiscount:
          pickDouble(json, const ['specialIdDiscount', 'specialDiscount']) ?? 0,
      coupon: couponCode == null ? null : AppliedCoupon.fromJson(couponJson),
      totalDiscount: pickDouble(json, const ['totalDiscount']) ?? 0,
    );
  }

  bool get hasDiscount => totalDiscount > 0;
}

/// VAT as applied to the discounted subtotal.
class VatDetail {
  const VatDetail({this.percentage = 0, this.amount = 0});

  final double percentage;
  final double amount;

  factory VatDetail.fromJson(Map<String, dynamic> json) {
    return VatDetail(
      percentage:
          pickDouble(json, const ['percentage', 'percent', 'rate']) ?? 0,
      amount: pickDouble(json, const ['amount', 'value']) ?? 0,
    );
  }
}

/// The authoritative price breakdown for the session.
///
/// Invariant maintained by the backend:
/// `subtotal = baseFare - discounts.totalDiscount`, and
/// `totalAmount = subtotal + vat.amount`.
class CheckoutPricing {
  const CheckoutPricing({
    required this.currency,
    required this.baseFare,
    required this.discounts,
    required this.subtotal,
    required this.vat,
    required this.totalAmount,
    required this.isZeroCheckout,
  });

  final String currency;
  final double baseFare;
  final PricingDiscounts discounts;
  final double subtotal;
  final VatDetail vat;
  final double totalAmount;

  /// When true the booking confirms without any payment step at all — the
  /// discount covered the full fare.
  final bool isZeroCheckout;

  factory CheckoutPricing.fromJson(Map<String, dynamic> json) {
    final total = pickDouble(json, const ['totalAmount', 'total']) ?? 0;
    return CheckoutPricing(
      currency: pickString(json, const ['currency']) ?? 'SAR',
      baseFare: pickDouble(json, const ['baseFare', 'fare', 'charge']) ?? 0,
      discounts: PricingDiscounts.fromJson(pickMap(json, const ['discounts'])),
      subtotal: pickDouble(json, const ['subtotal']) ?? 0,
      vat: VatDetail.fromJson(pickMap(json, const ['vat'])),
      totalAmount: total,
      // Trust the server's flag, but fall back to the amount so a missing flag
      // can never route a free booking into the payment SDK.
      isZeroCheckout:
          pickBool(json, const ['isZeroCheckout', 'zeroCheckout']) ??
          (total <= 0),
    );
  }
}

/// A checkout view: the session summary plus its pricing.
///
/// Returned by `GET /checkout` and by both coupon endpoints, so applying or
/// removing a coupon refreshes the whole screen from one response.
class CheckoutDetails {
  const CheckoutDetails({required this.summary, required this.pricing});

  final BookingSession summary;
  final CheckoutPricing pricing;

  factory CheckoutDetails.fromJson(Map<String, dynamic> json) {
    return CheckoutDetails(
      summary: BookingSession.fromJson(pickMap(json, const ['summary'])),
      pricing: CheckoutPricing.fromJson(pickMap(json, const ['pricing'])),
    );
  }
}

/// PayTabs SDK parameters issued by the backend on confirm.
///
/// These replace the values previously read from `.env`: the amount and cart id
/// are bound to a `PaymentTransaction` the server already created, so the client
/// cannot charge an amount the server did not authorise.
class PaytabsSessionConfig {
  const PaytabsSessionConfig({
    required this.profileId,
    required this.serverKey,
    required this.clientKey,
    required this.cartId,
    required this.cartDescription,
    required this.amount,
    required this.currency,
  });

  final String profileId;
  final String serverKey;
  final String clientKey;
  final String cartId;
  final String cartDescription;
  final double amount;
  final String currency;

  factory PaytabsSessionConfig.fromJson(Map<String, dynamic> json) {
    return PaytabsSessionConfig(
      profileId: pickString(json, const ['profileId', 'profile_id']) ?? '',
      serverKey: pickString(json, const ['serverKey', 'server_key']) ?? '',
      clientKey: pickString(json, const ['clientKey', 'client_key']) ?? '',
      cartId: pickString(json, const ['cartId', 'cart_id']) ?? '',
      cartDescription:
          pickString(json, const ['cartDescription', 'cart_description']) ??
          'Premium Force Booking',
      amount: pickDouble(json, const ['amount']) ?? 0,
      currency: pickString(json, const ['currency']) ?? 'SAR',
    );
  }

  bool get isUsable =>
      profileId.isNotEmpty &&
      serverKey.isNotEmpty &&
      clientKey.isNotEmpty &&
      amount > 0;

  /// Whether the credentials are shaped like real PayTabs keys.
  ///
  /// The keys have a fixed hyphen-grouped form — three ten-character groups for
  /// the server key, four six-character groups for the client key — and the
  /// profile id is numeric. The backend has been seen returning truncated
  /// placeholders (an 11-character server key, say) which pass [isUsable] but
  /// cannot open the gateway, so the shape is checked before they are trusted.
  bool get hasValidCredentials =>
      int.tryParse(profileId) != null &&
      _serverKeyPattern.hasMatch(serverKey) &&
      _clientKeyPattern.hasMatch(clientKey);

  static final RegExp _serverKeyPattern = RegExp(
    r'^[A-Z0-9]{10}(-[A-Z0-9]{10}){2}$',
    caseSensitive: false,
  );

  static final RegExp _clientKeyPattern = RegExp(
    r'^[A-Z0-9]{6}(-[A-Z0-9]{6}){3}$',
    caseSensitive: false,
  );
}

/// Result of `POST /bookings/session/confirm`.
///
/// Two outcomes: either the booking is already `confirmed` because the total was
/// zero, or a booking exists in `pending_payment` and [paytabsConfig] carries the
/// parameters for the SDK. Either way the booking row exists *before* any money
/// moves.
class ConfirmBookingResult {
  const ConfirmBookingResult({
    required this.paymentRequired,
    this.bookingId,
    this.bookingNumber,
    this.status,
    this.paytabsConfig,
    this.pricing,
    this.summary,
    this.message,
  });

  final bool paymentRequired;
  final String? bookingId;

  /// Human-readable reference, e.g. `PF-APT-2608-9842`. Doubles as the PayTabs
  /// cart id and as the key for `verify-payment`.
  final String? bookingNumber;

  /// Present on the zero-checkout path, e.g. `confirmed`.
  final String? status;

  /// Present only when [paymentRequired] is true.
  final PaytabsSessionConfig? paytabsConfig;

  final CheckoutPricing? pricing;
  final BookingSession? summary;
  final String? message;

  factory ConfirmBookingResult.fromJson(Map<String, dynamic> json) {
    final configJson = pickMap(json, const ['paytabsConfig', 'paytabs']);
    final pricingJson = pickMap(json, const ['pricing']);
    final summaryJson = pickMap(json, const ['summary']);

    return ConfirmBookingResult(
      // Default to requiring payment only when a config actually arrived, so a
      // malformed response fails closed rather than silently confirming.
      paymentRequired:
          pickBool(json, const ['paymentRequired']) ?? configJson.isNotEmpty,
      bookingId: pickId(json, const ['bookingId', '_id', 'id']),
      bookingNumber: pickString(json, const ['bookingNumber']),
      status: pickString(json, const ['status', 'bookingStatus']),
      paytabsConfig: configJson.isEmpty
          ? null
          : PaytabsSessionConfig.fromJson(configJson),
      pricing: pricingJson.isEmpty
          ? null
          : CheckoutPricing.fromJson(pricingJson),
      summary: summaryJson.isEmpty
          ? null
          : BookingSession.fromJson(summaryJson),
      message: pickString(json, const ['message']),
    );
  }
}

/// Gateway transaction state reported by `verify-payment`.
enum PaymentStatusV2 {
  /// Transaction opened; the customer has not completed payment yet.
  initiated('initiated'),

  /// Submitted, awaiting 3-D Secure or bank clearance — PayTabs `H`.
  pending('pending'),

  /// Authorised and charged — PayTabs `A`.
  captured('captured'),

  /// Declined, abandoned or cancelled — PayTabs `D`.
  failed('failed'),

  unknown('unknown');

  const PaymentStatusV2(this.wireValue);

  final String wireValue;

  static PaymentStatusV2 fromWire(String? value) {
    final normalised = value?.trim().toLowerCase().replaceAll('-', '_');
    if (normalised == null || normalised.isEmpty) return unknown;

    for (final status in values) {
      if (status.wireValue == normalised) return status;
    }

    // Tolerate the gateway's own vocabulary leaking through.
    return switch (normalised) {
      'paid' || 'authorised' || 'authorized' || 'success' => captured,
      'declined' || 'cancelled' || 'canceled' || 'error' => failed,
      'hold' || 'processing' || 'in_progress' => pending,
      _ => unknown,
    };
  }
}

/// What the app should do next, from the endpoint's UI guidance matrix.
enum PaymentVerificationOutcome {
  /// `captured` / `confirmed` — show the booking success screen.
  confirmed,

  /// `failed` / `payment_failed` — show the declined screen with a retry.
  failed,

  /// `initiated` or `pending` / `pending_payment` — keep polling.
  pending,
}

/// Result of `POST /bookings/session/verify-payment`.
///
/// The endpoint is read-only: it mutates nothing and queries PayTabs live when
/// the stored status is not yet captured, which is what makes it safe to poll.
/// The backend is the arbiter of whether the charge actually settled — the SDK
/// callback alone is not treated as proof.
class PaymentVerificationResult {
  const PaymentVerificationResult({
    required this.paymentStatus,
    this.bookingId,
    this.bookingNumber,
    this.bookingStatus,
    this.transactionRef,
    this.paidAmount,
    this.currency,
    this.message,
    bool? confirmedFlag,
  }) : _confirmedFlag = confirmedFlag;

  final PaymentStatusV2 paymentStatus;

  /// Booking lifecycle state, e.g. `pending_payment`, `confirmed`,
  /// `payment_failed`, or any of the post-confirmation driver states.
  final String? bookingStatus;

  final String? bookingId;
  final String? bookingNumber;
  final String? transactionRef;
  final double? paidAmount;
  final String? currency;
  final String? message;

  /// Explicit verdict, when the backend sends one; it wins over the statuses.
  final bool? _confirmedFlag;

  /// Booking states that mean the ride is live — anything at or past
  /// confirmation settles the payment question.
  static const Set<String> _settledBookingStatuses = {
    'confirmed',
    'driver_assigned',
    'driver_en_route',
    'driver_arrived',
    'trip_started',
    'completed',
  };

  factory PaymentVerificationResult.fromJson(Map<String, dynamic> json) {
    // The documented payload is flat; a nested `payment` block is still read in
    // case the endpoint returns the older shape.
    final payment = pickMap(json, const ['payment']);

    return PaymentVerificationResult(
      paymentStatus: PaymentStatusV2.fromWire(
        pickString(json, const ['paymentStatus']) ??
            pickString(payment, const ['status', 'paymentStatus']),
      ),
      bookingStatus: pickString(json, const [
        'bookingStatus',
        'status',
      ])?.toLowerCase(),
      bookingId: pickId(json, const ['bookingId', '_id', 'id']),
      bookingNumber: pickString(json, const ['bookingNumber']),
      transactionRef: pickString(json, const [
        'transactionRef',
        'transactionReference',
      ]),
      paidAmount: pickDouble(json, const ['paidAmount', 'amount']),
      currency: pickString(json, const ['currency']),
      message: pickString(json, const ['message']),
      confirmedFlag: pickBool(json, const [
        'isConfirmed',
        'confirmed',
        'verified',
      ]),
    );
  }

  /// What to do next with this result.
  ///
  /// A capture settles it even if the booking row has not caught up yet — the
  /// money is taken, so the booking will confirm. Anything still with the
  /// gateway is [PaymentVerificationOutcome.pending] and should be polled.
  PaymentVerificationOutcome get outcome {
    if (_confirmedFlag == true) return PaymentVerificationOutcome.confirmed;

    final booking = bookingStatus?.replaceAll('-', '_');

    if (paymentStatus == PaymentStatusV2.captured ||
        (booking != null && _settledBookingStatuses.contains(booking))) {
      return PaymentVerificationOutcome.confirmed;
    }

    if (paymentStatus == PaymentStatusV2.failed ||
        booking == 'payment_failed' ||
        booking == 'cancelled') {
      return PaymentVerificationOutcome.failed;
    }

    return PaymentVerificationOutcome.pending;
  }

  bool get isConfirmed => outcome == PaymentVerificationOutcome.confirmed;

  /// Whether the gateway has not decided yet, so polling should continue.
  bool get isPending => outcome == PaymentVerificationOutcome.pending;
}
