/// Paytabs configuration constants
/// Update these values with your actual credentials from Paytabs merchant dashboard
class PaytabsConfig {
  // ===== REQUIRED: Update with your credentials =====
  /// Your Paytabs server key (from merchant dashboard)
  static const String serverKey = 'YOUR_SERVER_KEY';

  /// Your Paytabs client key (from merchant dashboard)
  static const String clientKey = 'YOUR_CLIENT_KEY';

  /// Your merchant email
  static const String merchantEmail = 'your-merchant@example.com';

  // ===== Country codes (update based on where you operate) =====
  /// Merchant country code (e.g., 'AE' for UAE, 'SA' for Saudi Arabia)
  static const String merchantCountryCode = 'AE';

  // ===== Currency settings =====
  /// Default currency for transactions (ISO 4217 code)
  static const String defaultCurrency = 'AED'; // UAE Dirham
  
  // Alternative currencies
  static const String currencyUSD = 'USD';
  static const String currencySAR = 'SAR'; // Saudi Riyal
  static const String currencyKWD = 'KWD'; // Kuwaiti Dinar

  // ===== Payment configuration =====
  /// Enable 3D Secure (recommended for security)
  static const bool enable3DSecure = true;

  /// Hide shipping address if not needed
  static const bool hideShippingAddress = false;

  /// Show billing address
  static const bool showBillingAddress = true;

  // ===== API Endpoints (if using backend) =====
  /// Base URL for your backend API (used for payment verification)
  static const String apiBaseUrl = 'https://your-api.com/api';

  /// Payment verification endpoint
  static const String paymentVerifyEndpoint = '/payments/verify';

  /// Payment creation endpoint
  static const String paymentCreateEndpoint = '/payments/create';
}
