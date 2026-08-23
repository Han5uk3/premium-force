import 'package:flutter/foundation.dart';
import 'package:premium_force_main/models/payment_model.dart';
import 'package:premium_force_main/services/payment_service.dart';

class PaymentProvider extends ChangeNotifier {
  final PaymentService _paymentService = PaymentService();

  PaymentResult? _lastPaymentResult;
  bool _isProcessing = false;
  String? _error;

  PaymentResult? get lastPaymentResult => _lastPaymentResult;
  bool get isProcessing => _isProcessing;
  String? get error => _error;

  /// Initialize payment service
  Future<void> initializePayment() async {
    try {
      _setProcessing(true);
      _clearError();
      await _paymentService.initPayment();
    } catch (e) {
      _setError('Failed to initialize payment: $e');
    } finally {
      _setProcessing(false);
    }
  }

  /// Process payment
  Future<bool> processPayment({required PaymentRequest request}) async {
    try {
      _setProcessing(true);
      _clearError();

      _lastPaymentResult = await _paymentService.startPayment(request: request);

      if (_lastPaymentResult?.success ?? false) {
        return true;
      } else {
        _setError(_lastPaymentResult?.responseMessage ?? 'Payment failed');
        return false;
      }
    } catch (e) {
      _setError('Payment error: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// Query payment status
  Future<QueryTransactionResult?> queryPaymentStatus({
    required String serverKey,
    required String clientKey,
    required String merchantCountryCode,
    required String transactionReference,
  }) async {
    try {
      _setProcessing(true);
      _clearError();

      final result = await _paymentService.queryTransaction(
        serverKey: serverKey,
        clientKey: clientKey,
        merchantCountryCode: merchantCountryCode,
        transactionReference: transactionReference,
      );

      return result;
    } catch (e) {
      _setError('Query status error: $e');
      return null;
    } finally {
      _setProcessing(false);
    }
  }

  /// Process recurring payment
  Future<bool> processRecurringPayment({
    required PaymentRequest request,
    required String agreementId,
  }) async {
    try {
      _setProcessing(true);
      _clearError();

      _lastPaymentResult = await _paymentService.startRecurringPayment(
        request: request,
        agreementId: agreementId,
      );

      if (_lastPaymentResult?.success ?? false) {
        return true;
      } else {
        _setError(
          _lastPaymentResult?.responseMessage ?? 'Recurring payment failed',
        );
        return false;
      }
    } catch (e) {
      _setError('Recurring payment error: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// Clear last payment result
  void clearLastPaymentResult() {
    _lastPaymentResult = null;
    notifyListeners();
  }

  void _setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}
