import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/borderedcontainer.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/home/home.dart';
import 'package:flutter/services.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:premium_force_main/theme/app_theme.dart';

class PaymentCancelledPage extends StatefulWidget {
  const PaymentCancelledPage({super.key});

  @override
  State<PaymentCancelledPage> createState() => _PaymentCancelledPageState();
}

class _PaymentCancelledPageState extends State<PaymentCancelledPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _buttonAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
    );

    _slideAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 0.8, curve: Curves.easeOutBack),
    );

    _buttonAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.overlayStyle(c.brightness),
        child: Scaffold(
          backgroundColor: c.accentSurface,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Background Gradient/Image
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: size.height * 0.45,
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage(
                        c.brightness == Brightness.dark
                            ? "assets/images/homeappbar.jpeg"
                            : "assets/images/homeappbarlight.jpeg",
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: size.height * 0.45,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        c.brightness == Brightness.light
                            ? c.accentSurface.withValues(alpha: 0.7)
                            : const Color(0xFF1E1105).withValues(alpha: 0.7),
                        c.brightness == Brightness.light
                            ? c.accentSurface
                            : c.accentSurface.withValues(alpha: 0.9),
                        c.accentSurface,
                      ],
                      stops: const [0.3, 0.9, 1.0],
                    ),
                  ),
                ),
              ),

              // Main Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // Animated Cancel Icon
                      ScaleTransition(
                        scale: _scaleAnimation,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Subtle outer glow
                            AnimatedBuilder(
                              animation: _scaleAnimation,
                              builder: (context, child) {
                                return Container(
                                  width: size.width * 0.45,
                                  height: size.width * 0.45,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: c.error.withValues(
                                      alpha: 0.05 * _scaleAnimation.value,
                                    ),
                                    border: Border.all(
                                      color: c.error.withValues(
                                        alpha: 0.1 * _scaleAnimation.value,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                );
                              },
                            ),
                            Container(
                              width: size.width * 0.35,
                              height: size.width * 0.35,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    c.error.withValues(alpha: 0.1),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.cancel_outlined,
                                color: c.error,
                                size: 100,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Animated Text Title
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: AnimatedBuilder(
                          animation: _slideAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                0,
                                30 * (1 - _slideAnimation.value),
                              ),
                              child: child,
                            );
                          },
                          child: Text(
                            l10n.paymentCancelled,
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Animated Description
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: AnimatedBuilder(
                          animation: _slideAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                0,
                                40 * (1 - _slideAnimation.value),
                              ),
                              child: child,
                            );
                          },
                          child: Text(
                            l10n.paymentCancelledDescription,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ),

                      const Spacer(flex: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: FadeTransition(
            opacity: _buttonAnimation,
            child: AnimatedBuilder(
              animation: _buttonAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 50 * (1 - _buttonAnimation.value)),
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  top: 12,
                ),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const Home(isfromSuccessPage: false),
                            ),
                            (route) => false,
                          );
                        },
                        child: PremiumContainer(
                          height: 48,
                          width: size.width,
                          child: Center(
                            child: Text(
                              l10n.backToHome,
                              style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: PremiumButton(
                        text: l10n.tryAgain,
                        onTap: () {
                          Navigator.pop(context);
                        },
                        fontsize: 14,
                        showLoader: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
