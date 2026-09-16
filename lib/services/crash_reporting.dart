import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Sends crashes and uncaught errors to Firebase Crashlytics.
///
/// Collection is off in debug builds, so a developer's hot-reload mistakes do
/// not bury real field crashes in the console. Everything still goes to the
/// debug console there as usual.
///
/// Usage:
/// ```dart
/// await Firebase.initializeApp(...);
/// await CrashReporting.init();
/// ```
class CrashReporting {
  CrashReporting._();

  static FirebaseCrashlytics get _crashlytics => FirebaseCrashlytics.instance;

  /// Install the error hooks. Call once, straight after `Firebase.initializeApp`
  /// — anything thrown before this runs is not reported.
  static Future<void> init() async {
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Errors inside the framework: build, layout and paint failures.
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _crashlytics.recordFlutterFatalError(details);
    };

    // Everything else that escapes to the root zone — mostly un-awaited
    // futures that throw.
    PlatformDispatcher.instance.onError = (error, stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Tag every later report with the signed-in customer, so a crash can be
  /// matched to the account that hit it. Pass null on logout.
  ///
  /// Only the backend id is sent — never the phone number or name.
  static Future<void> setUser(String? userId) async {
    try {
      await _crashlytics.setUserIdentifier(userId ?? '');
    } catch (_) {
      // Reporting is best-effort; it must never break a login or a logout.
    }
  }

  /// Report an error that was caught and handled, but is still worth knowing
  /// about.
  static Future<void> recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
  }) async {
    try {
      await _crashlytics.recordError(error, stack, reason: reason);
    } catch (_) {}
  }
}
