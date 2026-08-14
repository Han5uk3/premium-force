import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_paytabs_bridge/BaseBillingShippingInfo.dart';
import 'package:flutter_paytabs_bridge/PaymentSDKNetworks.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkConfigurationDetails.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkLocale.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkTokeniseType.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkTransactionType.dart';
import 'package:flutter_paytabs_bridge/flutter_paytabs_bridge.dart';
import 'package:premium_force_main/models/payment_model.dart';
import 'package:premium_force_main/models/v2/checkout_models.dart';
import 'package:premium_force_main/utils/paytabs_config.dart';
import 'package:premium_force_main/utils/paytabs_theme.dart';

/// Launches the PayTabs SDK using gateway parameters issued by the backend.
///
/// This is the v2 counterpart to [PaymentService]. The profile id, keys, cart
/// id, **amount** and currency all arrive in the `POST /bookings/session/confirm`
/// response, bound to a `PaymentTransaction` the server already created, so the
/// client cannot charge an amount the backend did not authorise.
///
/// The one concession to a misbehaving backend is [_credentials], which falls
/// back to the app's live keys when the issued ones are malformed. In debug
/// builds it instead forces the sandbox profile, so test cards never touch the
/// live merchant account.
///
/// The SDK result is *not* treated as proof of payment — callers must follow up
/// with `verifyPayment` so the backend settles the booking against the gateway.
///
/// Usage:
/// ```dart
/// final result = await SessionPaymentService().startCardPayment(
///   config: confirmation.paytabsConfig!,
///   customerName: name, customerEmail: email, customerPhone: phone,
/// );
/// ```
class SessionPaymentService {
  static final SessionPaymentService _instance =
      SessionPaymentService._internal();
  factory SessionPaymentService() => _instance;
  SessionPaymentService._internal();

  /// The gateway credentials to open the SDK with.
  ///
  /// The backend's are used whenever they are well-formed. It has been seen
  /// returning truncated placeholders that are non-empty but cannot open the
  /// gateway, so anything failing [PaytabsSessionConfig.hasValidCredentials]
  /// falls back to the app's live keys.
  ///
  /// All three move together: a profile id and keys belong to one PayTabs
  /// profile and cannot be mixed across sources.
  ///
  /// Debug builds short-circuit to the sandbox profile — see below.
  static ({String profileId, String serverKey, String clientKey}) _credentials(
    PaytabsSessionConfig config,
  ) {
    // Debug builds charge the sandbox profile, so the card sheet can be
    // exercised with PayTabs test cards instead of real money. Release is
    // untouched and still prefers the backend's credentials.
    //
    // Scope of this override: the backend issues the cart id and amount
    // against its own (live) profile, so a payment made here exists only in
    // sandbox and `verifyPayment` will not settle the booking. It validates
    // the SDK sheet and the gateway handshake, not the end-to-end flow.
    //
    // Falls through when the sandbox keys are absent, rather than opening the
    // gateway with empty credentials.
    if (kDebugMode &&
        PaytabsConfig.sandboxServerKey.isNotEmpty &&
        PaytabsConfig.sandboxClientKey.isNotEmpty) {
      debugPrint(
        '🧪 Session payment │ DEBUG build — ignoring backend credentials, '
        'using sandbox profile "${PaytabsConfig.sandboxProfileId}". '
        'No real money moves.',
      );
      return (
        profileId: PaytabsConfig.sandboxProfileId,
        serverKey: PaytabsConfig.sandboxServerKey,
        clientKey: PaytabsConfig.sandboxClientKey,
      );
    }

    if (config.hasValidCredentials) {
      return (
        profileId: config.profileId,
        serverKey: config.serverKey,
        clientKey: config.clientKey,
      );
    }

    // Lengths only — the keys themselves stay out of the log.
    debugPrint(
      '⚠️  Session payment │ Backend credentials malformed '
      '(profile "${config.profileId}", server ${config.serverKey.length} chars, '
      'client ${config.clientKey.length} chars) — using app live keys',
    );

    return (
      profileId: PaytabsConfig.liveProfileId,
      serverKey: PaytabsConfig.liveServerKey,
      clientKey: PaytabsConfig.liveClientKey,
    );
  }

  /// Present the card payment sheet for [config].
  Future<PaymentResult> startCardPayment({
    required PaytabsSessionConfig config,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String merchantCountryCode = 'SA',
  }) {
    return _start(
      config: config,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      merchantCountryCode: merchantCountryCode,
      useApplePay: false,
    );
  }

  /// Present the Apple Pay sheet for [config]. iOS only.
  Future<PaymentResult> startApplePayPayment({
    required PaytabsSessionConfig config,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    String merchantCountryCode = 'SA',
  }) {
    if (!Platform.isIOS) {
      return Future.value(
        _failure(
          config: config,
          customerEmail: customerEmail,
          code: 'UNSUPPORTED',
          message: 'Apple Pay is only available on iOS devices',
        ),
      );
    }

    return _start(
      config: config,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      merchantCountryCode: merchantCountryCode,
      useApplePay: true,
    );
  }

  Future<PaymentResult> _start({
    required PaytabsSessionConfig config,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String merchantCountryCode,
    required bool useApplePay,
  }) async {
    final completer = Completer<PaymentResult>();

    debugPrint(
      '💳 Session payment │ cart=${config.cartId} '
      'amount=${config.amount} ${config.currency} applePay=$useApplePay',
    );

    final credentials = _credentials(config);

    try {
      // PayTabs rejects empty billing fields, so fall back to merchant defaults
      // rather than sending blanks the user never entered.
      final billingDetails = BillingDetails(
        customerName,
        customerEmail,
        customerPhone,
        'Saudi Arabia',
        merchantCountryCode,
        'Riyadh',
        'Riyadh',
        '00000',
      );

      final configuration = PaymentSdkConfigurationDetails(
        // Cart and amount are always the backend's; the credentials are its
        // too unless they arrived malformed — see [_credentials].
        profileId: credentials.profileId,
        serverKey: credentials.serverKey,
        clientKey: credentials.clientKey,
        cartId: config.cartId,
        cartDescription: config.cartDescription,
        merchantName: 'Premium Force',
        screentTitle: useApplePay ? 'Apple Pay' : 'Pay with Card',
        amount: config.amount,
        showBillingInfo: false,
        showShippingInfo: false,
        isDigitalProduct: true,
        currencyCode: config.currency,
        merchantCountryCode: merchantCountryCode,
        billingDetails: billingDetails,
        locale: PaymentSdkLocale.EN,
        transactionType: PaymentSdkTransactionType.SALE,
        tokeniseType: PaymentSdkTokeniseType.NONE,
        simplifyApplePayValidation: true,
        paymentNetworks: [
          PaymentSDKNetworks.visa,
          PaymentSDKNetworks.masterCard,
          PaymentSDKNetworks.mada,
          PaymentSDKNetworks.amex,
        ],
        merchantApplePayIndentifier: useApplePay
            ? PaytabsConfig.applePayMerchantId
            : null,
      );

      configuration.iOSThemeConfigurations = buildPremiumForceTheme();

      void onEvent(dynamic event) {
        // The SDK callback is the only record of what the gateway decided, so
        // it is logged raw before being interpreted.
        debugPrint('💳 PayTabs event │ cart=${config.cartId} │ $event');

        if (completer.isCompleted) return;

        final result = _mapEvent(
          event,
          config: config,
          customerEmail: customerEmail,
        );
        debugPrint(
          '💳 PayTabs result │ success=${result.success} '
          'code=${result.responseCode} ref=${result.transactionReference} '
          'msg=${result.responseMessage}',
        );

        completer.complete(result);
      }

      void onBridgeError(Object error) {
        debugPrint('❌ Session payment bridge error: $error');
        if (completer.isCompleted) return;
        completer.complete(
          _failure(
            config: config,
            customerEmail: customerEmail,
            code: 'ERROR',
            message: error.toString(),
          ),
        );
      }

      // Launch without awaiting so the completer future is what callers get.
      if (useApplePay) {
        FlutterPaytabsBridge.startApplePayPayment(
          configuration,
          onEvent,
        ).catchError(onBridgeError);
      } else {
        FlutterPaytabsBridge.startCardPayment(
          configuration,
          onEvent,
        ).catchError(onBridgeError);
      }

      return completer.future;
    } catch (error) {
      debugPrint('❌ Session payment failed to start: $error');
      return _failure(
        config: config,
        customerEmail: customerEmail,
        code: 'EXCEPTION',
        message: error.toString(),
      );
    }
  }

  /// Translate an SDK callback into a [PaymentResult].
  ///
  /// The bridge reports four shapes: `success` (with a nested `isSuccess`),
  /// `error`, `event` (internal, including user cancellation), and, on some SDK
  /// versions, a bare `cancel` status.
  PaymentResult _mapEvent(
    dynamic event, {
    required PaytabsSessionConfig config,
    required String customerEmail,
  }) {
    final map = event is Map ? event : const {};
    final status = (map['status'] ?? 'UNKNOWN').toString().toLowerCase();
    final message = map['message']?.toString();

    if (status == 'success') {
      final details = map['data'];
      final detailsMap = details is Map ? details : const {};
      final paymentResult = detailsMap['paymentResult'];
      final resultMap = paymentResult is Map ? paymentResult : const {};
      final isSuccess = detailsMap['isSuccess'] == true;

      return PaymentResult(
        success: isSuccess,
        transactionReference:
            detailsMap['transactionReference']?.toString() ?? '',
        invoiceId: detailsMap['cartId']?.toString() ?? config.cartId,
        responseCode:
            resultMap['responseCode']?.toString() ??
            (isSuccess ? '000' : 'ERR'),
        responseMessage:
            resultMap['responseMessage']?.toString() ??
            (isSuccess ? 'Success' : 'Payment Failed'),
        agreementId: detailsMap['agreementId']?.toString(),
        customerEmail: customerEmail,
        amount: config.amount,
      );
    }

    final isCancellation =
        status == 'cancel' || message?.toLowerCase() == 'cancel';

    return _failure(
      config: config,
      customerEmail: customerEmail,
      code: isCancellation ? 'CANCELLED' : status.toUpperCase(),
      message: isCancellation
          ? 'Payment Cancelled'
          : (message ?? 'Transaction failed or was stopped'),
    );
  }

  PaymentResult _failure({
    required PaytabsSessionConfig config,
    required String customerEmail,
    required String code,
    required String message,
  }) {
    return PaymentResult(
      success: false,
      transactionReference: '',
      invoiceId: config.cartId,
      responseCode: code,
      responseMessage: message,
      customerEmail: customerEmail,
      amount: config.amount,
    );
  }
}

/// Whether a failed [PaymentResult] represents the user backing out rather than
/// a decline, which decides between the cancelled and rejected screens.
bool isUserCancellation(PaymentResult result) {
  final code = result.responseCode.toUpperCase();
  final message = result.responseMessage.toLowerCase();
  return code == 'CANCELLED' ||
      code == 'EVENT_CANCELLED' ||
      code == 'CANCEL' ||
      message.contains('cancel');
}
