import 'package:flutter/material.dart';
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
        debugPrint('💾 User already logged in & active — skipping login');
        Navigator.pushReplacement(context, SmoothNavigation.route(Home()));
      } else {
        debugPrint('⛔ User is blocked — redirecting to BlockedPage');
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
    return Scaffold(
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
    );
  }
}
