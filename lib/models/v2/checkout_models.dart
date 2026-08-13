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

/// Result of `POST /bookings/session/verify-payment`.
///
/// The backend is the arbiter of whether the charge actually settled — the SDK
/// callback alone is not treated as proof.
class PaymentVerificationResult {
  const PaymentVerificationResult({
    required this.isConfirmed,
    this.bookingId,
    this.bookingNumber,
    this.bookingStatus,
    this.paymentStatus,
    this.transactionRef,
    this.message,
  });

  final bool isConfirmed;
  final String? bookingId;
  final String? bookingNumber;
  final String? bookingStatus;
  final String? paymentStatus;
  final String? transactionRef;
  final String? message;

  factory PaymentVerificationResult.fromJson(Map<String, dynamic> json) {
    final payment = pickMap(json, const ['payment']);
    final bookingStatus = pickString(json, const [
      'bookingStatus',
      'status',
    ])?.toLowerCase();
    final paymentStatus = pickString(payment, const ['status'])?.toLowerCase();

    return PaymentVerificationResult(
      isConfirmed:
          pickBool(json, const ['isConfirmed', 'confirmed', 'verified']) ??
          // Fall back to the settled states the backend documents.
          (bookingStatus == 'confirmed' ||
              paymentStatus == 'captured' ||
              paymentStatus == 'paid'),
      bookingId: pickId(json, const ['bookingId', '_id', 'id']),
      bookingNumber: pickString(json, const ['bookingNumber']),
      bookingStatus: bookingStatus,
      paymentStatus: paymentStatus,
      transactionRef: pickString(json, const [
        'transactionRef',
        'transactionReference',
      ]),
      message: pickString(json, const ['message']),
    );
  }
}
