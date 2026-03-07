import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:premium_force_main/splashscreen/splashscreen.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:premium_force_main/providers/user_provider.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:premium_force_main/firebase_options.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/services/notification_service.dart';


/// Global navigator key – allows navigating from outside a widget tree
/// (e.g. when the user taps a push notification).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
 
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await UserLocalStorage.init();

  // Initialise push notifications
  await NotificationService.instance.init();

  // Optional: react to notification taps globally
  NotificationService.instance.onNotificationTap = _handleNotificationTap;

  runApp(const MainApp());
}

/// Invoked when the user taps a notification (foreground banner, tray, or
/// when the app is launched from a terminated-state notification).
void _handleNotificationTap(RemoteMessage message) {
  debugPrint('🔔 Notification tapped │ data: ${message.data}');
  // TODO: implement navigation based on message.data payload.
  // Example:
  //   final type = message.data['type'];
  //   if (type == 'booking_update') {
  //     navigatorKey.currentState?.pushNamed('/bookings');
  //   }
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
  Locale _locale = const Locale('en');

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: "Premium Force",
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        locale: _locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home:
            // Home(),
            SplashScreen(),
      ),
    );
  }
}
