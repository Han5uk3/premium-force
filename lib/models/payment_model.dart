import 'package:equatable/equatable.dart';

/// Payment request model for starting a payment transaction
class PaymentRequest extends Equatable {
  final double amount;
  final String currency;
  final String merchantCountryCode;
  final String orderId;
  final String customerEmail;
  final String customerName;
  final String customerPhone;
  final String cartId;
  final String cartDescription;

  const PaymentRequest({
    required this.amount,
    required this.currency,
    required this.merchantCountryCode,
    required this.orderId,
    required this.customerEmail,
    required this.customerName,
    required this.customerPhone,
    required this.cartId,
    required this.cartDescription,
  });

  @override
  List<Object?> get props => [
    amount,
    currency,
    merchantCountryCode,
    orderId,
    customerEmail,
    customerName,
    customerPhone,
    cartId,
    cartDescription,
  ];

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'currency': currency,
      'merchantCountryCode': merchantCountryCode,
      'orderId': orderId,
      'customerEmail': customerEmail,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'cartId': cartId,
      'cartDescription': cartDescription,
    };
  }
}

/// Payment result model for transaction response
class PaymentResult extends Equatable {
  final bool success;
  final String transactionReference;
  final String invoiceId;
  final String responseCode;
  final String responseMessage;
  final String? agreementId;
  final String customerEmail;
  final double amount;

  const PaymentResult({
    required this.success,
    required this.transactionReference,
    required this.invoiceId,
    required this.responseCode,
    required this.responseMessage,
    this.agreementId,
    required this.customerEmail,
    required this.amount,
  });

  @override
  List<Object?> get props => [
    success,
    transactionReference,
    invoiceId,
    responseCode,
    responseMessage,
    agreementId,
    customerEmail,
    amount,
  ];

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'transactionReference': transactionReference,
      'invoiceId': invoiceId,
      'responseCode': responseCode,
      'responseMessage': responseMessage,
      'agreementId': agreementId,
      'customerEmail': customerEmail,
      'amount': amount,
    };
  }

  factory PaymentResult.fromJson(Map<String, dynamic> json) {
    return PaymentResult(
      success: json['success'] as bool? ?? false,
      transactionReference: json['transactionReference'] as String? ?? '',
      invoiceId: json['invoiceId'] as String? ?? '',
      responseCode: json['responseCode'] as String? ?? '',
      responseMessage: json['responseMessage'] as String? ?? '',
      agreementId: json['agreementId'] as String?,
      customerEmail: json['customerEmail'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Query transaction result model
class QueryTransactionResult extends Equatable {
  final bool success;
  final String transactionStatus;
  final String responseCode;
  final String responseMessage;
  final String transactionReference;

  const QueryTransactionResult({
    required this.success,
    required this.transactionStatus,
    required this.responseCode,
    required this.responseMessage,
    required this.transactionReference,
  });

  @override
  List<Object?> get props => [
    success,
    transactionStatus,
    responseCode,
    responseMessage,
    transactionReference,
  ];

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'transactionStatus': transactionStatus,
      'responseCode': responseCode,
      'responseMessage': responseMessage,
      'transactionReference': transactionReference,
    };
  }
}
