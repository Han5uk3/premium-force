import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_main/authentication/blocked_page.dart';
import 'package:premium_force_main/authentication/login.dart';
import 'package:premium_force_main/home/home.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Defer so the widget tree finishes building before AuthProvider
    // calls notifyListeners().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateAfterSplash();
    });
  }

  Future<void> _navigateAfterSplash() async {
    // Show splash for at least 3 seconds while checking auth in parallel
    final authCheck = context.read<AuthProvider>().checkAuth();
    await Future.wait([authCheck, Future.delayed(const Duration(seconds: 3))]);

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();

    if (authProvider.status == AuthStatus.authenticated &&
        authProvider.user != null) {
      // User is logged in and data was fetched → check if active
      if (authProvider.user!.isActive) {
        Navigator.pushReplacement(context, SmoothNavigation.route(Home()));
      } else {
        Navigator.pushReplacement(
          context,
          SmoothNavigation.route(const BlockedPage()),
        );
      }
    } else {
      // Not logged in or fetch failed → go to Login
      Navigator.pushReplacement(
        context,
        SmoothNavigation.route(const PremiumForceLoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The splash stays dark in both themes, and deliberately so: it is a
    // full-bleed photograph with the logo reversed out of it, so there is
    // nothing here for a palette to colour — only artwork. The status bar is
    // pinned to light icons to match it, whichever theme the app then opens in.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Container(
              height: double.infinity,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/splashimage.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Container(
              height: double.infinity,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.3,
                  colors: [Colors.transparent, Colors.black.withAlpha(180)],
                  stops: const [0.4, 1.0],
                  center: Alignment.center,
                ),
              ),
            ),
            Center(
              child: Image.asset(
                'assets/applogo/premiumforcelogo.png',
                width: MediaQuery.of(context).size.width / 1.8,
                height: 300,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
