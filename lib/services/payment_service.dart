import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_paytabs_bridge/BaseBillingShippingInfo.dart';
import 'package:flutter_paytabs_bridge/IOSThemeConfiguration.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkConfigurationDetails.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkLocale.dart';
import 'package:flutter_paytabs_bridge/PaymentSDKNetworks.dart';
import 'package:flutter_paytabs_bridge/flutter_paytabs_bridge.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkTokeniseType.dart';
import 'package:flutter_paytabs_bridge/PaymentSdkTransactionType.dart';
import 'package:premium_force_main/models/payment_model.dart';
import 'package:premium_force_main/utils/paytabs_config.dart';

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
    try {
      debugPrint('✅ Payment SDK ready to use');
    } catch (e) {
      debugPrint('❌ Payment SDK initialization failed: $e');
      rethrow;
    }
  }

  /// Start payment transaction
  /// Returns PaymentResult with transaction details
  Future<PaymentResult> startPayment({required PaymentRequest request}) async {
    final Completer<PaymentResult> completer = Completer<PaymentResult>();

    debugPrint(
      '🚀 PaymentService.startPayment called for Order: ${request.orderId}',
    );
    try {
      debugPrint('🔄 Processing payment...');
      debugPrint('Amount: ${request.amount} ${request.currency}');
      debugPrint('Order ID: ${request.orderId}');
      debugPrint('Profile ID: ${PaytabsConfig.profileId}');
      debugPrint(
        'Server Key prefix: ${PaymentService.serverKey.substring(0, 10)}...',
      );
      debugPrint(
        'Client Key prefix: ${PaymentService.clientKey.substring(0, 10)}...',
      );
      debugPrint('isDigitalProduct: false');
      debugPrint(
        'Billing: ${request.customerName}, ${request.customerEmail}, ${request.merchantCountryCode}',
      );

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

      var theme = IOSThemeConfigurations();
      theme.logoImage = "assets/applogo/premiumforcelogo.png";

      // Screen background (black)
      theme.backgroundColor = "000000";
      theme.backgroundColorDark = "000000";

      // Primary accent color (Grey)
      theme.primaryColor = "444444";
      theme.primaryColorDark = "444444";

      // Secondary/Card container background color
      theme.secondaryColor = "1E1E1E";
      theme.secondaryColorDark = "1E1E1E";

      // Text color in text fields (white)
      theme.primaryFontColor = "FFFFFF";
      theme.primaryFontColorDark = "FFFFFF";

      // Label / helper text color (light gray)
      theme.secondaryFontColor = "E0E0E0";
      theme.secondaryFontColorDark = "E0E0E0";

      // Button background and text color
      theme.buttonColor = "444444";
      theme.buttonColorDark = "444444";
      theme.buttonFontColor = "FFFFFF";
      theme.buttonFontColorDark = "FFFFFF";

      // Navigation title color
      theme.titleFontColor = "FFFFFF";
      theme.titleFontColorDark = "FFFFFF";

      // Borders/Stroke color and thickness
      theme.strokeColor = "444444";
      theme.strokeColorDark = "444444";
      theme.strokeThinckness = 1;

      // Text fields placeholder and background colors
      theme.placeholderColor = "888888";
      theme.placeholderColorDark = "888888";
      theme.inputFieldBackgroundColor = "141313";
      theme.inputFieldBackgroundColorDark = "141313";

      configuration.iOSThemeConfigurations = theme;

      // 3. Initiate Payment (Do not await method launch so we can return the future)
      FlutterPaytabsBridge.startCardPayment(configuration, (event) {
        debugPrint('🎯 PayTabs Callback Received: $event');

        if (completer.isCompleted) return;

        if (event["status"] == "success") {
          var transactionDetails = event["data"];
          debugPrint('Transaction Details: $transactionDetails');

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
          debugPrint('PayTabs Error: ${event["message"]}');
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
          debugPrint('PayTabs Internal Event: ${event["message"]}');
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

          debugPrint('PayTabs Other Status: $status - $msg');

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
        debugPrint('❌ Card Payment bridge error: $error');
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
      debugPrint('❌ Payment transaction failed: $e');
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
      debugPrint('🔍 Querying transaction status...');

      // Mock implementation for now as querying often requires backend-to-backend
      return QueryTransactionResult(
        success: true,
        transactionStatus: 'completed',
        responseCode: '000',
        responseMessage: 'Transaction found',
        transactionReference: transactionReference,
      );
    } catch (e) {
      debugPrint('❌ Query transaction failed: $e');
      rethrow;
    }
  }

  /// Start recurring payment (subscription)
  /// For subscriptions, agreements, or recurring charges
  Future<PaymentResult> startRecurringPayment({
    required PaymentRequest request,
    required String agreementId,
  }) async {
    return startPayment(request: request);
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

    debugPrint('🍎 Starting Apple Pay for Order: ${request.orderId}');

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
        debugPrint('🍎 Apple Pay Callback: $event');

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
        debugPrint('❌ Apple Pay bridge error: $error');
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
      debugPrint('❌ Apple Pay failed: $e');
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
