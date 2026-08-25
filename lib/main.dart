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
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:premium_force_main/theme/app_theme.dart';
import 'package:premium_force_main/theme/theme_provider.dart';
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

/// The customer's bookings.
///
/// Created outside the widget tree for the same reason as the notification
/// centre: a push announcing that the driver is on the way has to be able to
/// re-read the bookings, and it arrives with no screen guaranteed to be
/// mounted. Living in the tree is what left the "track your driver" card
/// waiting for a manual pull-to-refresh.
final BookingProvider bookingProvider = BookingProvider();

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
    } catch (e) {}
  }

  // Lock to portrait mode only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load environment variables
  await dotenv.load(fileName: "lib/.env");

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
    } else {
      rethrow;
    }
  }
  await UserLocalStorage.init();

  // Initialise push notifications
  await NotificationService.instance.init();

  // Optional: react to notification taps globally
  NotificationService.instance.onNotificationTap = _handleNotificationTap;

  // A push only announces that something happened; both the feed and the
  // bookings are server-backed, so the app answers by re-reading them.
  //
  // The bookings matter as much as the feed here: `CUSTOMER.DRIVER_EN_ROUTE`
  // is what opens live tracking, and the home screen decides whether to offer
  // it from the booking's status. Refreshing only the feed left the customer
  // with a notification saying their driver was on the way and no way to watch
  // them without pulling the home screen down by hand.
  NotificationService.instance.onMessageReceived = (_) {
    notificationProvider.refresh(silent: true);
    bookingProvider.refreshBookings(silent: true);
  };

  runApp(const MainApp());
}

/// Invoked when the user taps a notification (foreground banner, tray, or
/// when the app is launched from a terminated-state notification).
void _handleNotificationTap(RemoteMessage message) {
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

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  Locale _locale = const Locale('ar');
  late final AuthProvider _authProvider;
  late final UserProvider _userProvider;

  /// Which theme the app paints, and which skin its maps wear.
  ///
  /// Built here rather than with `create:` on the provider so its constructor —
  /// which reads both choices straight out of Hive — has run before the first
  /// frame. A future resolving one frame late would show the app in the wrong
  /// mode and then flip it.
  late final ThemeProvider _themeProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authProvider = AuthProvider();
    _userProvider = UserProvider();
    _themeProvider = ThemeProvider();

    // Load the previously selected language from persistence
    _loadSavedLanguage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Repaint when the device flips its own dark-mode setting.
  ///
  /// [MaterialApp] handles this for everything below it. The one thing it does
  /// not cover is the strip behind the root [SafeArea], which is painted above
  /// it from the platform brightness directly — so on [ThemeMode.system] that
  /// strip needs this to stay in step.
  @override
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    if (mounted) setState(() {});
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

    UserApiV2().updateSettings(
      locale: languageCode,
      fcmToken: UserLocalStorage.getFcmToken(),
    );
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
        ChangeNotifierProvider.value(value: bookingProvider),
        ChangeNotifierProvider(create: (_) => PaymentProvider()),
        ChangeNotifierProvider.value(value: notificationProvider),
        ChangeNotifierProvider.value(value: _themeProvider),
      ],
      // Only the theme choice is watched here, so a booking or a notification
      // arriving does not rebuild the whole app under [MaterialApp].
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => ColoredBox(
          // The ground behind the [SafeArea]'s inset.
          //
          // Nothing else paints there — it is outside [MaterialApp], so what
          // shows through is the *native* window background, and Android picks
          // that from the OS's own dark-mode setting. A customer running the app
          // light on a dark phone would get a black band under it. This paints
          // the strip from the app's own theme instead.
          //
          // It cannot use `context.colors`: this sits above [MaterialApp], so
          // there is no theme here to read, and no MediaQuery either — hence the
          // platform brightness comes from the view and the observer above
          // rebuilds when it changes.
          color: _palette(themeProvider).scaffold,
          child: SafeArea(
            top: false,
            bottom: Platform.isAndroid ? isThickNavBar : false,
            child: MaterialApp(
              title: "Premium Force",
              debugShowCheckedModeBanner: false,
              navigatorKey: navigatorKey,
              locale: _locale,
              // Two full themes and the mode that picks between them. Every
              // colour either carries comes from [AppPalette], so the same widget
              // tree paints itself in whichever one is in force.
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeProvider.themeMode,
              // The status and navigation bars belong to the OS, not to any
              // widget, so nothing in the tree updates them on a theme change.
              // Stamping the style here covers every screen; a screen that floats
              // its bar over a map or a photo still overrides this with its own
              // [AnnotatedRegion] or app bar.
              builder: (context, child) =>
                  AnnotatedRegion<SystemUiOverlayStyle>(
                    value: AppTheme.overlayStyle(Theme.of(context).brightness),
                    child: child ?? const SizedBox.shrink(),
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
        ),
      ),
    );
  }

  /// The palette in force, resolved without a theme or a [MediaQuery].
  ///
  /// Only for the strip behind the root [SafeArea], which is painted above
  /// [MaterialApp] and so has neither to read.
  AppPalette _palette(ThemeProvider themeProvider) {
    final platform = View.of(context).platformDispatcher.platformBrightness;
    return themeProvider.brightnessFrom(platform) == Brightness.dark
        ? AppPalette.dark
        : AppPalette.light;
  }
}
