# Paytabs Integration - Quick Start

## 🚀 Fast Setup Checklist

### 1. Get Paytabs Credentials
```
✅ Visit https://www.paytabs.com
✅ Create merchant account
✅ Get Server Key & Client Key from dashboard
✅ Note your Merchant Email and Country Code
```

### 2. Update Configuration
Update these files with your credentials:

**`lib/utils/paytabs_config.dart`:**
```dart
static const String serverKey = 'YOUR_SERVER_KEY';
static const String clientKey = 'YOUR_CLIENT_KEY';
static const String merchantEmail = 'your-email@example.com';
static const String merchantCountryCode = 'AE';
```

**`lib/services/payment_service.dart`:**
```dart
static const String serverKey = 'YOUR_SERVER_KEY';
static const String clientKey = 'YOUR_CLIENT_KEY';
static const String merchantEmail = 'merchant@example.com';
```

### 3. Update main.dart
```dart
import 'package:premium_force_main/providers/payment_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // ... other initialization code ...
  
  // Initialize payment service
  await PaymentProvider().initializePayment();
  
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        // ... other providers ...
      ],
      child: MaterialApp(
        // ... your app config ...
      ),
    );
  }
}
```

### 4. Use Payment in Your Widget
```dart
import 'package:provider/provider.dart';
import 'package:premium_force_main/providers/payment_provider.dart';
import 'package:premium_force_main/models/payment_model.dart';

class BookingPaymentScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => _processPayment(context),
        child: const Text('Pay Now'),
      ),
    );
  }

  Future<void> _processPayment(BuildContext context) async {
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);
    
    final request = PaymentRequest(
      amount: 100.0,
      currency: 'AED',
      merchantCountryCode: 'AE',
      orderId: 'ORDER_123',
      customerEmail: 'customer@example.com',
      customerName: 'John Doe',
      customerPhone: '+971501234567',
      cartId: 'CART_123',
      cartDescription: 'Ride booking',
    );

    final success = await paymentProvider.processPayment(request: request);
    
    if (success) {
      final result = paymentProvider.lastPaymentResult;
      print('✅ Payment successful: ${result?.transactionReference}');
      // Navigate to success screen
    } else {
      print('❌ Payment failed: ${paymentProvider.error}');
      // Show error dialog
    }
  }
}
```

## 📁 Files Created

```
lib/
├── services/
│   └── payment_service.dart          # Payment SDK wrapper
├── models/
│   └── payment_model.dart             # Payment DTOs
├── providers/
│   └── payment_provider.dart          # State management
├── utils/
│   └── paytabs_config.dart           # Configuration
└── common_widgets/
    └── payment_example_screen.dart    # Example implementation

PAYTABS_SETUP.md                       # Detailed setup guide
setup_paytabs.sh                       # Automation script
```

## 🧪 Testing

### Test Cards (Sandbox)
| Type       | Number              |
|-----------|-------------------|
| Visa      | 4111 1111 1111 1111 |
| Mastercard| 5555 5555 5555 4444|
| CVV       | Any 3 digits       |
| Expiry    | Any future date    |

### Test Payment Flow
1. Create PaymentRequest with test data
2. Call `paymentProvider.processPayment(request)`
3. Enter test card details
4. Verify response in PaymentResult

## 🔐 Security

- ✅ Server key is safe on backend only
- ✅ Client key is safe to embed in app
- ✅ Never log sensitive card data
- ✅ Always verify payments on backend
- ✅ Use HTTPS for API calls

## 🛠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| SDK not initializing | Check server/client keys |
| Payment fails | Verify customer email format |
| iOS build error | Run `pod install --repo-update` |
| Android build error | Run `flutter clean && flutter pub get` |

## 📚 Resources

- Full Setup Guide: [PAYTABS_SETUP.md](PAYTABS_SETUP.md)
- Example Screen: [lib/common_widgets/payment_example_screen.dart](lib/common_widgets/payment_example_screen.dart)
- Paytabs Docs: https://paytabs.com/en/api

## ✅ Verification

After setup, verify:
```bash
✅ flutter pub get completes without errors
✅ Code files compile without errors
✅ PaymentProvider initializes successfully
✅ Test payment completes (use sandbox)
```

---

**Next:** Update your credentials and test with a sandbox payment! 🎉
