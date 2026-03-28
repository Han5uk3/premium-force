import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_main/providers/payment_provider.dart';
import 'package:premium_force_main/models/payment_model.dart';
import 'package:premium_force_main/utils/paytabs_config.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';

/// Example payment widget
/// This demonstrates how to integrate Paytabs payment in your app
class PaymentExampleScreen extends StatefulWidget {
  final double amount;
  final String orderId;
  final String cartDescription;

  const PaymentExampleScreen({
    Key? key,
    required this.amount,
    required this.orderId,
    required this.cartDescription,
  }) : super(key: key);

  @override
  State<PaymentExampleScreen> createState() => _PaymentExampleScreenState();
}

class _PaymentExampleScreenState extends State<PaymentExampleScreen> {
  late PaymentProvider _paymentProvider;

  @override
  void initState() {
    super.initState();
    _paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
  }

  /// Process payment
  Future<void> _handlePayment() async {
    // Create payment request
    final paymentRequest = PaymentRequest(
      amount: widget.amount,
      currency: PaytabsConfig.defaultCurrency,
      merchantCountryCode: PaytabsConfig.merchantCountryCode,
      orderId: widget.orderId,
      customerEmail: 'customer@example.com', // Replace with actual customer email
      customerName: 'John Doe', // Replace with actual customer name
      customerPhone: '+971501234567', // Replace with actual customer phone
      cartId: 'CART_${widget.orderId}',
      cartDescription: widget.cartDescription,
    );

    // Process payment
    final success = await _paymentProvider.processPayment(
      request: paymentRequest,
    );

    if (!mounted) return;

    if (success) {
      final result = _paymentProvider.lastPaymentResult;
      _showPaymentSuccessDialog(result!);
    } else {
      _showPaymentErrorDialog(_paymentProvider.error ?? 'Payment failed');
    }
  }

  void _showPaymentSuccessDialog(PaymentResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction ID: ${result.transactionReference}'),
            const SizedBox(height: 8),
            Text('Invoice ID: ${result.invoiceId}'),
            const SizedBox(height: 8),
            Text('Amount: ${result.amount} ${PaytabsConfig.defaultCurrency}'),
            if (result.agreementId != null) ...[
              const SizedBox(height: 8),
              Text('Agreement ID: ${result.agreementId}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPaymentErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Failed'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: Consumer<PaymentProvider>(
        builder: (context, paymentProvider, _) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Payment amount
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Order Total',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.amount} ${PaytabsConfig.defaultCurrency}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(widget.cartDescription),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Error message
                  if (paymentProvider.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Text(
                        paymentProvider.error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Payment button
                  ElevatedButton(
                    onPressed: paymentProvider.isProcessing ? null : _handlePayment,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 48,
                        vertical: 16,
                      ),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: paymentProvider.isProcessing
                        ? const PremiumLoader(
                            size: 24,
                            color: Colors.white,
                          )
                        : const Text('Pay Now'),
                  ),

                  const SizedBox(height: 24),

                  // Payment info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'Test Credentials:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Card: 4111 1111 1111 1111',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          'CVV: Any 3 digits',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          'Expiry: Any future date',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
