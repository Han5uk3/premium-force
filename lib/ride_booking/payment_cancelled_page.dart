import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/borderedcontainer.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/home/home.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';

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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background Gradient/Image
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              height: size.height * 0.45,
              child: ShaderMask(
                shaderCallback: (rect) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                      Colors.black,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  "assets/images/homeappbar.jpeg",
                  fit: BoxFit.cover,
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
                                  color: Colors.white.withValues(
                                    alpha: 0.05 * _scaleAnimation.value,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(
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
                                  Colors.white.withValues(alpha: 0.1),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.cancel_outlined,
                              color: Colors.white54,
                              size: 80,
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
                            offset: Offset(0, 30 * (1 - _slideAnimation.value)),
                            child: child,
                          );
                        },
                        child: const Text(
                          "Payment Cancelled",
                          style: TextStyle(
                            color: Colors.white,
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
                            offset: Offset(0, 40 * (1 - _slideAnimation.value)),
                            child: child,
                          );
                        },
                        child: Text(
                          "The payment process was cancelled. No charges were made to your account.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
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
                bottom: 40,
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
                            builder: (context) => const Home(isfromSuccessPage: false),
                          ),
                          (route) => false,
                        );
                      },
                      child: PremiumContainer(
                        height: 60,
                        width: size.width,
                        child: Center(
                          child: Text(
                            l10n.backToHome,
                            style: const TextStyle(
                              color: Colors.white,
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
                      textColor: Colors.black,
                      text: "Try Again",
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
    );
  }
}
