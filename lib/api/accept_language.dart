import 'package:premium_force_main/storage/user_local_storage.dart';

/// The header every request to our backend carries the app's language in.
const String acceptLanguageHeader = 'Accept-Language';

/// The app's current language, as an `Accept-Language` value.
///
/// Read per request rather than baked into a client's `BaseOptions`: the
/// clients are singletons built once at launch, so a header set there would
/// keep sending whatever language was selected then, and every request after a
/// language switch would still ask for the old one.
///
/// The quality-weighted fallback is what the header is for — it tells the
/// backend "Arabic, but English will do", so an endpoint that has not been
/// translated yet answers in something readable instead of falling back to a
/// language the customer did not pick. `en` is the second choice in both
/// directions because it is the one language every payload is known to have.
///
/// [UserLocalStorage.getLanguage] defaults to `ar`, which is also the app's
/// own default, so the two cannot disagree.
String currentAcceptLanguage() {
  final language = UserLocalStorage.getLanguage().trim().toLowerCase();
  return language == 'en' ? 'en, ar;q=0.8' : 'ar, en;q=0.8';
}
