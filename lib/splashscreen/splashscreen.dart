import 'package:flutter/material.dart';
import 'package:premium_force_main/authentication/login.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Future.delayed(Duration(seconds: 3), () {
      if (!context.mounted) return;
      Navigator.pushReplacement(
        context,
        SmoothNavigation.route(const PremiumForceLoginPage()),
      );
    });
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
