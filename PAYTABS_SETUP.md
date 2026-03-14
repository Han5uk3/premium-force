# Flutter Paytabs Bridge Setup Guide

## Overview
This guide walks you through setting up `flutter_paytabs_bridge` for payments in your Premium Force app.

## Prerequisites
- Paytabs merchant account (https://www.paytabs.com)
- Server Key and Client Key from Paytabs dashboard
- iOS deployment target: 15.0 or higher
- Android: minSdk 21 or higher (already configured in your project)

## Step 1: Get Your Credentials

1. Log in to your Paytabs merchant dashboard
2. Navigate to **Settings > API Keys**
3. Copy your **Server Key** and **Client Key**
4. Copy your **Merchant Email**

## Step 2: Update Configuration

Edit `lib/utils/paytabs_config.dart`:
```dart
static const String serverKey = 'YOUR_SERVER_KEY';
static const String clientKey = 'YOUR_CLIENT_KEY';
static const String merchantEmail = 'your-merchant@example.com';
static const String merchantCountryCode = 'AE'; // Update with your country code
```

Also update `lib/services/payment_service.dart`:
```dart
static const String serverKey = 'YOUR_SERVER_KEY';
static const String clientKey = 'YOUR_CLIENT_KEY';
static const String merchantEmail = 'merchant@example.com';
```

## Step 3: iOS Configuration

### 3.1 Update Info.plist
Run the following command from the iOS folder:
```bash
cd ios
```

Add the following to `ios/Runner/Info.plist` inside the `<dict>` tags:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Payment SDK requires local network access</string>
<key>NSBonjourServices</key>
<array>
  <string>_paytabs._tcp</string>
</array>
<key>URLSchemes</key>
<array>
  <string>paytabs</string>
</array>
```

### 3.2 Update Podfile (if needed)
The standard `flutter pub get` should handle pod dependencies, but if you encounter issues:

```bash
flutter clean
flutter pub get
cd ios
pod repo update
pod install --repo-update
cd ..
```

## Step 4: Android Configuration

The Paytabs bridge handles most Android configuration automatically. However, ensure:

1. Your `android/app/build.gradle.kts` has proper network permissions
2. `AndroidManifest.xml` includes internet permissions (should be default)

To verify Android setup:
```bash
cd android
./gradlew dependencies | grep paytabs
```

## Step 5: Integrate into Your App

### 5.1 Add PaymentProvider to main.dart
```dart
import 'package:premium_force_main/providers/payment_provider.dart';

// In MultiProvider:
providers: [
  ChangeNotifierProvider(create: (_) => PaymentProvider()),
  // ... other providers
]
```

### 5.2 Initialize Payment Service
In your main.dart or a startup screen:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... other initialization
  
  // Initialize payment service
  final paymentProvider = PaymentProvider();
  await paymentProvider.initializePayment();
  
  runApp(const MainApp());
}
```

## Step 6: Use Payment Service

### Example: Simple Payment
```dart
import 'package:premium_force_main/providers/payment_provider.dart';
import 'package:premium_force_main/models/payment_model.dart';

// In a widget:
final paymentProvider = Provider.of<PaymentProvider>(context);

final request = PaymentRequest(
  amount: 100.0,
  currency: 'AED',
  merchantCountryCode: 'AE',
  orderId: 'ORDER_001',
  customerEmail: user.email,
  customerName: user.name,
  customerPhone: user.phone,
  cartId: 'CART_001',
  cartDescription: 'Ride booking payment',
);

final success = await paymentProvider.processPayment(request: request);

if (success) {
  final result = paymentProvider.lastPaymentResult;
  print('Transaction: ${result?.transactionReference}');
  // Save transaction to backend
} else {
  print('Error: ${paymentProvider.error}');
}
```

### Example: Recurring Payment (Subscription)
```dart
final success = await paymentProvider.processRecurringPayment(
  request: request,
  agreementId: 'SUBSCRIPTION_123',
);
```

### Example: Query Payment Status
```dart
final queryResult = await paymentProvider.queryPaymentStatus(
  serverKey: PaytabsConfig.serverKey,
  clientKey: PaytabsConfig.clientKey,
  merchantCountryCode: PaytabsConfig.merchantCountryCode,
  transactionReference: 'transaction_id_here',
);

if (queryResult?.success ?? false) {
  print('Status: ${queryResult?.transactionStatus}');
}
```

## Step 7: Backend Integration

Update your backend API to verify payments:
1. Send transaction details to your backend after successful payment
2. Use server-to-server verification with Paytabs API
3. Store payment records in your database

### Example backend endpoint (Node.js):
```javascript
// routes/payments.js
router.post('/verify', async (req, res) => {
  const { transactionReference, amount, orderId } = req.body;
  
  try {
    // Verify with Paytabs
    const verification = await verifyPaymentWithPaytabs(transactionReference);
    
    if (verification.success) {
      // Save to database
      await Payment.create({
        orderId,
        amount,
        transactionReference,
        status: 'completed',
        userId: req.user.id
      });
      
      res.json({ success: true, message: 'Payment verified' });
    } else {
      res.status(400).json({ success: false, message: 'Verification failed' });
    }
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});
```

## Step 8: Testing

### Test Cards (Sandbox Mode)
Paytabs provides test cards for development:
- **Visa**: 4111 1111 1111 1111
- **Mastercard**: 5555 5555 5555 4444
- **CVV**: Any 3 digits
- **Expiry**: Any future date

### Test Flow:
1. Make sure your keys are from sandbox environment
2. Process a test payment
3. Verify transaction in Paytabs dashboard
4. Switch to live keys when ready for production

## Troubleshooting

### Payment SDK Not Initializing
- Verify server key and client key are correct
- Check internet connectivity
- Clear build cache: `flutter clean`

### iOS Build Errors
```bash
cd ios
rm -rf Pods
rm Podfile.lock
pod install --repo-update
cd ..
flutter pub get
flutter run
```

### Android Build Errors
```bash
flutter clean
flutter pub get
cd android
./gradlew clean build
cd ..
```

### Transaction Failures
- Check merchant country code matches your Paytabs account settings
- Verify amount format (decimal places)
- Ensure customer email is valid
- Check response message in PaymentResult for specific error details

## Security Best Practices

1. ✅ Never commit credentials to version control - use environment variables
2. ✅ Use HTTPS for all backend communication
3. ✅ Validate all payments on backend before updating records
4. ✅ Store server key securely on backend only
5. ✅ Use client key for SDK initialization (it's safe to embed)
6. ✅ Never store card details - let Paytabs handle sensitive data
7. ✅ Implement PCI DSS compliance for your payment system

## Production Deployment

1. Update credentials to live keys from Paytabs merchant dashboard
2. Test thoroughly in live environment with small amounts
3. Implement proper error logging and monitoring
4. Set up email notifications for payment events
5. Configure backup payment methods if possible
6. Document your payment flow for support team

## API Reference

### PaymentRequest
- `amount`: Double - payment amount
- `currency`: String - ISO 4217 currency code
- `merchantCountryCode`: String - merchant country code
- `orderId`: String - unique order identifier
- `customerEmail`: String - customer email
- `customerName`: String - customer name
- `customerPhone`: String - customer phone number
- `cartId`: String - shopping cart identifier
- `cartDescription`: String - payment description

### PaymentResult
- `success`: Boolean - transaction success status
- `transactionReference`: String - Paytabs transaction ID
- `invoiceId`: String - invoice identifier
- `responseCode`: String - response code from Paytabs
- `responseMessage`: String - response message
- `agreementId`: String? - for recurring payments

## Support & Resources

- Paytabs Documentation: https://paytabs.com/en/api
- Flutter Paytabs Bridge: https://pub.dev/packages/flutter_paytabs_bridge
- Issue Tracker: https://github.com/paytabs/flutter-bridge

## Next Steps

1. ✅ Update `paytabs_config.dart` with your credentials
2. ✅ Run `flutter pub get` to fetch dependencies
3. ✅ Run `flutter run` to test the integration
4. ✅ Test with sandbox cards
5. ✅ Deploy to production with live keys
