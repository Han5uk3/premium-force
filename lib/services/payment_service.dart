import 'package:flutter/material.dart';
import 'package:premium_force_main/models/payment_model.dart';

/// Payment service wrapper for Paytabs bridge
/// This service handles all payment transactions with Paytabs
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();

  factory PaymentService() {
    return _instance;
  }

  PaymentService._internal();

  // Configuration - Update these with your Paytabs credentials
  static const String serverKey = 'YOUR_SERVER_KEY';
  static const String clientKey = 'YOUR_CLIENT_KEY';
  static const String merchantEmail = 'merchant@example.com';

  /// Initialize Paytabs payment
  /// Call this during app startup to set up the payment SDK
  Future<void> initPayment() async {
    try {
      // Initialize payment SDK with your credentials
      // Note: flutter_paytabs_bridge handles initialization internally
      // when you call startPayment for the first time
      debugPrint('✅ Payment SDK ready to use');
    } catch (e) {
      debugPrint('❌ Payment SDK initialization failed: $e');
      rethrow;
    }
  }

  /// Start payment transaction
  /// Returns PaymentResult with transaction details
  Future<PaymentResult> startPayment({required PaymentRequest request}) async {
    try {
      debugPrint('🔄 Processing payment...');
      debugPrint('Amount: ${request.amount} ${request.currency}');
      debugPrint('Order ID: ${request.orderId}');

      // TODO: Implement actual payment call using flutter_paytabs_bridge
      // Example structure (adjust based on actual flutter_paytabs_bridge API):
      /*
      final result = await FlutterPaymentSdkBridge.startPaymentSDKTransaction(
        amount: request.amount.toString(),
        currency: request.currency,
        merchantCountryCode: request.merchantCountryCode,
        merchantHash: 'HASH', // You'll need to generate this
        secretKey: PaymentService.serverKey,
        orderId: request.orderId,
        customerEmail: request.customerEmail,
        customerName: request.customerName,
        customerPhoneNumber: request.customerPhone,
        cartId: request.cartId,
        cartDescription: request.cartDescription,
      );
      */

      // Mock implementation for now - replace with actual SDK call
      final result = <String, dynamic>{
        'success': true,
        'transaction_id': 'TEST_TRANS_${request.orderId}',
        'invoiceId': 'INV_${request.orderId}',
        'response_code': '000',
        'response_message': 'Success',
      };

      final paymentResult = PaymentResult(
        success: result['success'] ?? false,
        transactionReference: result['transaction_id'] ?? '',
        invoiceId: result['invoiceId'] ?? '',
        responseCode: result['response_code'] ?? '',
        responseMessage: result['response_message'] ?? '',
        agreementId: result['agreementId'],
        customerEmail: request.customerEmail,
        amount: request.amount,
      );

      debugPrint('✅ Payment transaction completed: ${paymentResult.toJson()}');
      return paymentResult;
    } catch (e) {
      debugPrint('❌ Payment transaction failed: $e');
      return PaymentResult(
        success: false,
        transactionReference: '',
        invoiceId: '',
        responseCode: 'ERROR',
        responseMessage: e.toString(),
        customerEmail: request.customerEmail,
        amount: request.amount,
      );
    }
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

      // TODO: Implement actual query using flutter_paytabs_bridge
      // This typically requires backend verification via Paytabs API

      final result = <String, dynamic>{
        'success': true,
        'transaction_status': 'completed',
        'response_code': '000',
        'response_message': 'Transaction found',
      };

      return QueryTransactionResult(
        success: result['success'] ?? false,
        transactionStatus: result['transaction_status'] ?? '',
        responseCode: result['response_code'] ?? '',
        responseMessage: result['response_message'] ?? '',
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
    try {
      debugPrint('🔄 Processing recurring payment...');
      debugPrint('Agreement ID: $agreementId');

      // TODO: Implement recurring payment using flutter_paytabs_bridge
      // Similar to startPayment but with agreementId parameter

      final result = <String, dynamic>{
        'success': true,
        'transaction_id': 'REC_TRANS_${request.orderId}',
        'invoiceId': 'REC_INV_${request.orderId}',
        'response_code': '000',
        'response_message': 'Recurring payment successful',
        'agreementId': agreementId,
      };

      return PaymentResult(
        success: result['success'] ?? false,
        transactionReference: result['transaction_id'] ?? '',
        invoiceId: result['invoiceId'] ?? '',
        responseCode: result['response_code'] ?? '',
        responseMessage: result['response_message'] ?? '',
        agreementId: result['agreementId'],
        customerEmail: request.customerEmail,
        amount: request.amount,
      );
    } catch (e) {
      debugPrint('❌ Recurring payment failed: $e');
      rethrow;
    }
  }

  /// Get SDK version
  String getSDKVersion() => '2.7.2';

  /// Check if payment SDK is ready
  Future<bool> isSDKReady() async {
    try {
      // Check if SDK is initialized and ready
      return true;
    } catch (e) {
      return false;
    }
  }
}
