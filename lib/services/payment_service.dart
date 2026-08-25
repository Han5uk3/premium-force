import 'dart:async';
import 'dart:io';
import 'package:flutter_paytabs_bridge/BaseBillingShippingInfo.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkConfigurationDetails.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkLocale.dart';
import 'package:flutter_paytabs_bridge/PaymentSDKNetworks.dart';
import 'package:flutter_paytabs_bridge/flutter_paytabs_bridge.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkTokeniseType.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkTransactionType.dart';
import 'package:premium_force_main/models/payment_model.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:premium_force_main/utils/paytabs_config.dart';
import 'package:premium_force_main/utils/paytabs_theme.dart';

/// Payment service wrapper for Paytabs bridge
/// This service handles all payment transactions with Paytabs
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();

  factory PaymentService() {
    return _instance;
  }

  PaymentService._internal();

  // Configuration - Now using PaytabsConfig (loaded from .env)
  static String get serverKey => PaytabsConfig.serverKey;
  static String get clientKey => PaytabsConfig.clientKey;
  static String get merchantEmail => PaytabsConfig.merchantEmail;

  /// Initialize Paytabs payment
  /// Call this during app startup to set up the payment SDK
  Future<void> initPayment() async {
    try {} catch (e) {
      rethrow;
    }
  }

  /// Start payment transaction
  /// Returns PaymentResult with transaction details
  ///
  /// [palette] is the theme the gateway sheet should be drawn in. It defaults
  /// to the dark one, which is what this path shipped with; a caller that knows
  /// the app's current theme should pass it.
  Future<PaymentResult> startPayment({
    required PaymentRequest request,
    AppPalette palette = AppPalette.dark,
  }) async {
    final Completer<PaymentResult> completer = Completer<PaymentResult>();

    try {
      // 1. Configure Billing & Shipping Details
      var billingDetails = BillingDetails(
        request.customerName,
        request.customerEmail,
        request.customerPhone,
        request.billingAddress.isNotEmpty
            ? request.billingAddress
            : "Saudi Arabia", // Address
        request.merchantCountryCode,
        request.billingCity.isNotEmpty ? request.billingCity : "Riyadh", // City
        request.billingState.isNotEmpty
            ? request.billingState
            : "Riyadh", // State
        request.billingZip.isNotEmpty ? request.billingZip : "00000", // Zip
      );

      var shippingDetails = ShippingDetails(
        request.customerName,
        request.customerEmail,
        request.customerPhone,
        request.billingAddress.isNotEmpty
            ? request.billingAddress
            : "Saudi Arabia", // Address
        request.merchantCountryCode,
        request.billingCity.isNotEmpty ? request.billingCity : "Riyadh", // City
        request.billingState.isNotEmpty
            ? request.billingState
            : "Riyadh", // State
        request.billingZip.isNotEmpty ? request.billingZip : "00000", // Zip
      );

      // 2. Setup Configuration
      var configuration = PaymentSdkConfigurationDetails(
        profileId: PaytabsConfig.profileId,
        serverKey: PaymentService.serverKey,
        clientKey: PaymentService.clientKey,
        cartId: request.cartId,
        cartDescription: request.cartDescription,
        merchantName: "Premium Force",
        screentTitle: "Pay with Card",
        amount: request.amount,
        showBillingInfo: false,
        showShippingInfo: false,
        isDigitalProduct: true,
        currencyCode: request.currency,
        merchantCountryCode: request.merchantCountryCode,
        billingDetails: billingDetails,
        shippingDetails: shippingDetails,
        locale: PaymentSdkLocale.EN,
        transactionType: PaymentSdkTransactionType.SALE,
        tokeniseType: PaymentSdkTokeniseType.NONE,
        // tokenFormat: PaymentSdkTokenFormat.Hex32Format,
        simplifyApplePayValidation: true,
        paymentNetworks: [
          PaymentSDKNetworks.visa,
          PaymentSDKNetworks.masterCard,
          PaymentSDKNetworks.mada,
          PaymentSDKNetworks.amex,
        ],
      );

      // The same builder the session-driven service uses, so the two checkouts
      // cannot drift apart.
      configuration.iOSThemeConfigurations = buildPremiumForceTheme(palette);

      // 3. Initiate Payment (Do not await method launch so we can return the future)
      FlutterPaytabsBridge.startCardPayment(configuration, (event) {
        if (completer.isCompleted) return;

        if (event["status"] == "success") {
          var transactionDetails = event["data"];

          if (transactionDetails["isSuccess"]) {
            completer.complete(
              PaymentResult(
                success: true,
                transactionReference:
                    transactionDetails["transactionReference"] ?? '',
                invoiceId: transactionDetails["cartId"] ?? '',
                responseCode:
                    transactionDetails["paymentResult"]?["responseCode"] ??
                    '000',
                responseMessage:
                    transactionDetails["paymentResult"]?["responseMessage"] ??
                    'Success',
                agreementId: transactionDetails["agreementId"],
                customerEmail: request.customerEmail,
                amount: request.amount,
              ),
            );
          } else {
            completer.complete(
              PaymentResult(
                success: false,
                transactionReference: transactionReferenceFromMap(
                  transactionDetails,
                ),
                invoiceId: transactionDetails["cartId"] ?? '',
                responseCode:
                    transactionDetails["paymentResult"]?["responseCode"] ??
                    'ERR',
                responseMessage:
                    transactionDetails["paymentResult"]?["responseMessage"] ??
                    'Payment Failed',
                customerEmail: request.customerEmail,
                amount: request.amount,
              ),
            );
          }
        } else if (event["status"] == "error") {
          completer.complete(
            PaymentResult(
              success: false,
              transactionReference: '',
              invoiceId: '',
              responseCode: 'ERROR',
              responseMessage: event["message"] ?? 'Unknown Error',
              customerEmail: request.customerEmail,
              amount: request.amount,
            ),
          );
        } else if (event["status"] == "event") {
          if (!completer.isCompleted) {
            final msg = event["message"]?.toString().toLowerCase();
            completer.complete(
              PaymentResult(
                success: false,
                transactionReference: '',
                invoiceId: '',
                responseCode: 'EVENT_CANCELLED',
                responseMessage: msg == "cancel"
                    ? "Payment Cancelled"
                    : (event["message"] ?? 'Payment activity stopped'),
                customerEmail: request.customerEmail,
                amount: request.amount,
              ),
            );
          }
        } else {
          // Catch any other status (like direct 'cancel' in some SDK versions)
          final status = (event["status"] ?? 'UNKNOWN')
              .toString()
              .toLowerCase();
          final msg = (event["message"] ?? '').toString().toLowerCase();

          completer.complete(
            PaymentResult(
              success: false,
              transactionReference: '',
              invoiceId: '',
              responseCode: status.toUpperCase(),
              responseMessage: (status == "cancel" || msg == "cancel")
                  ? "Payment Cancelled"
                  : (event["message"] ?? 'Transaction failed or was stopped'),
              customerEmail: request.customerEmail,
              amount: request.amount,
            ),
          );
        }
      }).catchError((error) {
        if (!completer.isCompleted) {
          completer.complete(
            PaymentResult(
              success: false,
              transactionReference: '',
              invoiceId: '',
              responseCode: 'ERROR',
              responseMessage: error.toString(),
              customerEmail: request.customerEmail,
              amount: request.amount,
            ),
          );
        }
      });

      return completer.future;
    } catch (e) {
      return PaymentResult(
        success: false,
        transactionReference: '',
        invoiceId: '',
        responseCode: 'EXCEPTION',
        responseMessage: e.toString(),
        customerEmail: request.customerEmail,
        amount: request.amount,
      );
    }
  }

  String transactionReferenceFromMap(dynamic data) {
    if (data is Map && data.containsKey("transactionReference")) {
      return data["transactionReference"] ?? "";
    }
    return "";
  }

  /// Query transaction status
  /// Used to verify payment status after transaction
  Future<QueryTransactionResult> queryTransaction({
    required String serverKey,
    required String clientKey,
    required String merchantCountryCode,
    required String transactionReference,
  }) async {
    try {
      // Mock implementation for now as querying often requires backend-to-backend
      return QueryTransactionResult(
        success: true,
        transactionStatus: 'completed',
        responseCode: '000',
        responseMessage: 'Transaction found',
        transactionReference: transactionReference,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Start recurring payment (subscription)
  /// For subscriptions, agreements, or recurring charges
  Future<PaymentResult> startRecurringPayment({
    required PaymentRequest request,
    required String agreementId,
    AppPalette palette = AppPalette.dark,
  }) async {
    return startPayment(request: request, palette: palette);
  }

  /// Start Apple Pay payment (iOS only)
  /// Returns PaymentResult with transaction details
  Future<PaymentResult> startApplePayPayment({
    required PaymentRequest request,
  }) async {
    if (!Platform.isIOS) {
      return PaymentResult(
        success: false,
        transactionReference: '',
        invoiceId: '',
        responseCode: 'UNSUPPORTED',
        responseMessage: 'Apple Pay is only available on iOS devices',
        customerEmail: request.customerEmail,
        amount: request.amount,
      );
    }

    final Completer<PaymentResult> completer = Completer<PaymentResult>();

    try {
      var billingDetails = BillingDetails(
        request.customerName,
        request.customerEmail,
        request.customerPhone,
        request.billingAddress.isNotEmpty
            ? request.billingAddress
            : "Saudi Arabia",
        request.merchantCountryCode,
        request.billingCity.isNotEmpty ? request.billingCity : "Riyadh",
        request.billingState.isNotEmpty ? request.billingState : "Riyadh",
        request.billingZip.isNotEmpty ? request.billingZip : "00000",
      );

      var configuration = PaymentSdkConfigurationDetails(
        profileId: PaytabsConfig.profileId,
        serverKey: PaymentService.serverKey,
        clientKey: PaymentService.clientKey,
        cartId: request.cartId,
        cartDescription: request.cartDescription,
        merchantName: "Premium Force",
        amount: request.amount,
        currencyCode: request.currency,
        merchantCountryCode: request.merchantCountryCode,
        billingDetails: billingDetails,
        transactionType: PaymentSdkTransactionType.SALE,
        simplifyApplePayValidation: true,
        paymentNetworks: [
          PaymentSDKNetworks.visa,
          PaymentSDKNetworks.masterCard,
          PaymentSDKNetworks.mada,
          PaymentSDKNetworks.amex,
        ],
        merchantApplePayIndentifier: PaytabsConfig.applePayMerchantId,
      );

      // Do not await method launch so we can return the future
      FlutterPaytabsBridge.startApplePayPayment(configuration, (event) {
        if (completer.isCompleted) return;

        if (event["status"] == "success") {
          var transactionDetails = event["data"];
          if (transactionDetails["isSuccess"]) {
            completer.complete(
              PaymentResult(
                success: true,
                transactionReference:
                    transactionDetails["transactionReference"] ?? '',
                invoiceId: transactionDetails["cartId"] ?? '',
                responseCode:
                    transactionDetails["paymentResult"]?["responseCode"] ??
                    '000',
                responseMessage:
                    transactionDetails["paymentResult"]?["responseMessage"] ??
                    'Success',
                customerEmail: request.customerEmail,
                amount: request.amount,
              ),
            );
          } else {
            completer.complete(
              PaymentResult(
                success: false,
                transactionReference: transactionReferenceFromMap(
                  transactionDetails,
                ),
                invoiceId: transactionDetails["cartId"] ?? '',
                responseCode:
                    transactionDetails["paymentResult"]?["responseCode"] ??
                    'ERR',
                responseMessage:
                    transactionDetails["paymentResult"]?["responseMessage"] ??
                    'Payment Failed',
                customerEmail: request.customerEmail,
                amount: request.amount,
              ),
            );
          }
        } else if (event["status"] == "error" || event["status"] == "event") {
          completer.complete(
            PaymentResult(
              success: false,
              transactionReference: '',
              invoiceId: '',
              responseCode: 'CANCELLED',
              responseMessage: event["message"] ?? 'Apple Pay cancelled',
              customerEmail: request.customerEmail,
              amount: request.amount,
            ),
          );
        } else {
          final status = (event["status"] ?? 'UNKNOWN')
              .toString()
              .toUpperCase();
          completer.complete(
            PaymentResult(
              success: false,
              transactionReference: '',
              invoiceId: '',
              responseCode: status,
              responseMessage:
                  event["message"] ?? 'Apple Pay transaction stopped',
              customerEmail: request.customerEmail,
              amount: request.amount,
            ),
          );
        }
      }).catchError((error) {
        if (!completer.isCompleted) {
          completer.complete(
            PaymentResult(
              success: false,
              transactionReference: '',
              invoiceId: '',
              responseCode: 'ERROR',
              responseMessage: error.toString(),
              customerEmail: request.customerEmail,
              amount: request.amount,
            ),
          );
        }
      });

      return completer.future;
    } catch (e) {
      return PaymentResult(
        success: false,
        transactionReference: '',
        invoiceId: '',
        responseCode: 'EXCEPTION',
        responseMessage: e.toString(),
        customerEmail: request.customerEmail,
        amount: request.amount,
      );
    }
  }

  /// Get SDK version
  String getSDKVersion() => '2.7.6';

  /// Check if payment SDK is ready
  Future<bool> isSDKReady() async {
    return true;
  }

  /// Check if Apple Pay is available (iOS only)
  bool get isApplePayAvailable => Platform.isIOS;
}
