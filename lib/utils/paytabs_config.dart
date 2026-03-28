import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Paytabs configuration constants
/// Values are loaded from lib/.env file
class PaytabsConfig {
  // ===== REQUIRED: Loaded from .env =====
  /// Your Paytabs server key
  static String get serverKey => dotenv.get('PAYTABS_SERVER_KEY', fallback: '');

  /// Your Paytabs client key
  static String get clientKey => dotenv.get('PAYTABS_CLIENT_KEY', fallback: '');

  /// Your Paytabs profile ID
  static String get profileId => dotenv.get('PAYTABS_PROFILE_ID', fallback: '153721');

  /// Your merchant email
  static String get merchantEmail => dotenv.get('PAYTABS_MERCHANT_EMAIL', fallback: 'your-merchant@example.com');

  // ===== Country codes =====
  /// Merchant country code
  static String get merchantCountryCode => dotenv.get('PAYTABS_COUNTRY_CODE', fallback: 'SA');

  // ===== Currency settings =====
  /// Default currency for transactions
  static String get defaultCurrency => dotenv.get('PAYTABS_CURRENCY', fallback: 'SAR');
  
  // Alternative currencies
  static const String currencyUSD = 'USD';
  static const String currencySAR = 'SAR'; // Saudi Riyal
  static const String currencyKWD = 'KWD'; // Kuwaiti Dinar

  // ===== Payment configuration =====
  /// Enable 3D Secure
  static const bool enable3DSecure = true;

  /// Hide shipping address if not needed
  static const bool hideShippingAddress = false;

  /// Show billing address
  static const bool showBillingAddress = true;

  // ===== API Endpoints =====
  /// Base URL for your backend API
  static const String apiBaseUrl = 'https://your-api.com/api';

  /// Payment verification endpoint
  static const String paymentVerifyEndpoint = '/payments/verify';

  /// Payment creation endpoint
  static const String paymentCreateEndpoint = '/payments/create';
}
