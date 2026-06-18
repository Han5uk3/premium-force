import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Paytabs configuration constants
/// Values are loaded from lib/.env file
class PaytabsConfig {
  /// Helper to determine if we should use live PayTabs credentials.
  /// Release mode always uses live.
  /// On Android debug mode, we allow live credentials if PAYTABS_USE_LIVE_IN_ANDROID_DEBUG is 'true' (defaults to true).
  static bool get _useLiveKey {
    if (!kDebugMode) return true;
    if (!kIsWeb && Platform.isAndroid) {
      final useLiveInAndroidDebug = dotenv.get('PAYTABS_USE_LIVE_IN_ANDROID_DEBUG', fallback: 'true').toLowerCase() == 'true';
      return useLiveInAndroidDebug;
    }
    return false;
  }

  // ===== REQUIRED: Loaded from .env =====
  /// Your Paytabs server key
  static String get serverKey => _useLiveKey
      ? dotenv.get('PAYTABS_SERVER_LIVE_KEY', fallback: '')
      : dotenv.get('PAYTABS_SERVER_KEY', fallback: '');

  /// Your Paytabs client key
  static String get clientKey => _useLiveKey
      ? dotenv.get('PAYTABS_CLIENT_LIVE_KEY', fallback: '')
      : dotenv.get('PAYTABS_CLIENT_KEY', fallback: '');

  /// Your Paytabs profile ID
  static String get profileId => _useLiveKey
      ? dotenv.get('PAYTABS_PROFILE_LIVE_ID', fallback: '129739')
      : dotenv.get('PAYTABS_PROFILE_ID', fallback: '128366');

  /// Your merchant email
  static String get merchantEmail => dotenv.get('PAYTABS_MERCHANT_EMAIL', fallback: 'your-merchant@example.com');

  /// Apple Pay Merchant ID
  static String get applePayMerchantId => dotenv.get('PAYTABS_APPLE_PAY_MERCHANT_ID', fallback: 'merchant.com.brandbik.premiumforce');

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
