import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:premium_force_main/splashscreen/splashscreen.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:premium_force_main/providers/user_provider.dart';
import 'package:premium_force_main/providers/booking_provider.dart';
import 'package:premium_force_main/providers/payment_provider.dart';
import 'package:premium_force_main/providers/notification_provider.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:premium_force_main/firebase_options.dart';
import 'package:premium_force_main/api/user_api_v2.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/services/notification_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/services.dart';
import 'package:premium_force_main/notifications/notification_screen.dart';
import 'package:country_picker/country_picker.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Global navigator key – allows navigating from outside a widget tree
/// (e.g. when the user taps a push notification).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// The notification centre's state.
///
/// Created outside the widget tree so a push arriving before (or without) any
/// screen being mounted can still refresh the feed and the unread badge.
final NotificationProvider notificationProvider = NotificationProvider();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Flutter defaults the decoded-image cache to 100 MiB, which is larger than
  // the whole heap budget on low-RAM Android devices. Cap it so heavy fleet /
  // banner scrolling evicts instead of pushing the app into an OOM kill.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20; // 50 MiB
  PaintingBinding.instance.imageCache.maximumSize = 200;

  // Initialize Google Maps Android platform view & renderer optimizations
  final GoogleMapsFlutterPlatform mapsImplementation =
      GoogleMapsFlutterPlatform.instance;
  if (mapsImplementation is GoogleMapsFlutterAndroid) {
    mapsImplementation.useAndroidViewSurface = true;
    try {
      await mapsImplementation.initializeWithRenderer(
        AndroidMapRenderer.latest,
      );
      debugPrint(
        '🗺️ Google Maps Android renderer initialized with LATEST version successfully!',
      );
    } catch (e) {
      debugPrint('⚠️ Google Maps Android renderer initialization error: $e');
    }
  }

  // Lock to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for dark theme visibility
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light, // Android
      statusBarBrightness: Brightness.dark, // iOS
    ),
  );

  // Load environment variables
  await dotenv.load(fileName: "lib/.env");

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      debugPrint('⚠️ Firebase already initialized, skipping...');
    } else {
      rethrow;
    }
  }
  await UserLocalStorage.init();

  // Initialise push notifications
  await NotificationService.instance.init();

  // Optional: react to notification taps globally
  NotificationService.instance.onNotificationTap = _handleNotificationTap;

  // A push only announces that something happened; the notification centre is
  // server-backed, so the app answers by re-reading the feed.
  NotificationService.instance.onMessageReceived = (_) {
    notificationProvider.refresh(silent: true);
  };

  runApp(const MainApp());
}

/// Invoked when the user taps a notification (foreground banner, tray, or
/// when the app is launched from a terminated-state notification).
void _handleNotificationTap(RemoteMessage message) {
  debugPrint('🔔 Notification tapped │ data: ${message.data}');

  // Navigate to the notifications screen
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (context) => const NotificationScreen()),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _MainAppState? state = context.findAncestorStateOfType<_MainAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  Locale _locale = const Locale('ar');
  late final AuthProvider _authProvider;
  late final UserProvider _userProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _userProvider = UserProvider();

    // Load the previously selected language from persistence
    _loadSavedLanguage();
  }

  void _loadSavedLanguage() {
    final langCode = UserLocalStorage.getLanguage();
    setState(() {
      _locale = Locale(langCode);
    });
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    // Persist the selected language to Hive
    UserLocalStorage.saveLanguage(locale.languageCode);
    _syncLocaleWithBackend(locale.languageCode);
  }

  /// Mirror the chosen language onto the customer's account.
  ///
  /// Pushes and emails are rendered server-side, so the backend has to know
  /// which language to use. The call is fire-and-forget: the UI has already
  /// switched and Hive holds the choice, so a failure here only means the server
  /// keeps using the previous language until the next successful sync.
  void _syncLocaleWithBackend(String languageCode) {
    if (!UserLocalStorage.isLoggedIn) return;

    UserApiV2()
        .updateSettings(
          locale: languageCode,
          fcmToken: UserLocalStorage.getFcmToken(),
        )
        .then((result) {
          if (result.success) {
            debugPrint('🌐 Locale │ synced with backend: $languageCode');
          } else {
            debugPrint('🌐 Locale │ sync failed: ${result.message}');
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQueryData.fromView(
      View.of(context),
    ).padding.bottom;
    final bool isThickNavBar = bottomPadding >= 24.0;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider.value(value: _userProvider),
        ChangeNotifierProvider(create: (_) => BookingProvider()),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider.value(value: notificationProvider),
      ],
      child: SafeArea(
        top: false,
        bottom: Platform.isAndroid ? isThickNavBar : false,
        child: MaterialApp(
          title: "Premium Force",
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          locale: _locale,
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: Colors.black, // Assuming a dark theme
            appBarTheme: const AppBarTheme(
              systemOverlayStyle: SystemUiOverlayStyle.light,
            ),
          ),
          localizationsDelegates: [
            AppLocalizations.delegate,
            CountryLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SplashScreen(),
        ),
      ),
    );
  }
}
