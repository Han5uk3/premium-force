import 'package:flutter/material.dart';
import 'package:premium_force_main/common_widgets/borderedcontainer.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/home/home.dart';
import 'package:flutter/services.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:premium_force_main/theme/app_theme.dart';

class PaymentRejectedPage extends StatefulWidget {
  final String? errorMessage;
  const PaymentRejectedPage({super.key, this.errorMessage});

  @override
  State<PaymentRejectedPage> createState() => _PaymentRejectedPageState();
}

class _PaymentRejectedPageState extends State<PaymentRejectedPage>
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

  String _getProfessionalErrorMessage(String? error) {
    if (error == null || error.isEmpty) {
      return "Something went wrong with your payment. Please try again or use a different payment method.";
    }

    final lowerError = error.toLowerCase();

    if (lowerError.contains("3dsecure") ||
        lowerError.contains("authentication failed") ||
        lowerError.contains("3ds")) {
      return "Security verification failed. Please ensure your card details are correct or try a different payment method.";
    }

    if (lowerError.contains("insufficient funds") ||
        lowerError.contains("balance")) {
      return "The transaction was declined due to insufficient funds. Please check your account or use another card.";
    }

    if (lowerError.contains("declined") || lowerError.contains("reject")) {
      return "Your card was declined by the issuer. Please contact your bank or use a different payment method.";
    }

    if (lowerError.contains("expired")) {
      return "The card used has expired. Please provide a valid card and try again.";
    }

    return error;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final l10n = AppLocalizations.of(context)!;
    // Fixed rather than read from the context: this screen overrides the theme
    // for its whole subtree just below, so the palette it paints with is the
    // dark one whatever the app is set to.
    const c = AppPalette.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context);
      },
      // Pinned to the dark theme in both modes.
      //
      // This screen is a brand moment rather than a page of content: a dark
      // photograph fading into the ground, with the outcome mark reversed out
      // of it. A light theme with a dark full-screen takeover is the look here,
      // the same call the splash screen and the home header make. Wrapping the
      // subtree rather than hard-coding colours is what keeps the shared button
      // and container inside it consistent with the screen.
      child: Theme(
        data: AppTheme.dark,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.overlayStyle(Brightness.dark),
          child: Scaffold(
            backgroundColor: c.scaffold,
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
                    // A dstIn mask, so only the *alpha* of the stops below is
                    // read: the photograph is opaque at the top, fades out
                    // through the middle and returns at the bottom. Their
                    // colours never reach the screen, which is why they stay
                    // fixed while the rest of the page follows the theme.
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

                        // Animated Error Icon
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
                                        alpha: 0.1 * _scaleAnimation.value,
                                      ),
                                      border: Border.all(
                                        color: c.error.withValues(
                                          alpha: 0.2 * _scaleAnimation.value,
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
                                      c.error.withValues(alpha: 0.2),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                                child: Icon(
                                  Icons.error_outline_rounded,
                                  color: c.error,
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
                                offset: Offset(
                                  0,
                                  30 * (1 - _slideAnimation.value),
                                ),
                                child: child,
                              );
                            },
                            child: Text(
                              "Payment Rejected",
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
                              _getProfessionalErrorMessage(widget.errorMessage),
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
                                builder: (context) =>
                                    const Home(isfromSuccessPage: false),
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
        ),
      ),
    );
  }
}
