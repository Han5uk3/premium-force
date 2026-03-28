import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/authentication/signup.dart';
import 'package:premium_force_main/home/home.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';

class OTPVerificationPage extends StatefulWidget {
  final String countryCode;
  final String phoneNumber;
  const OTPVerificationPage({
    super.key,
    required this.countryCode,
    required this.phoneNumber,
  });

  @override
  State<OTPVerificationPage> createState() => _OTPVerificationPageState();
}

class _OTPVerificationPageState extends State<OTPVerificationPage> {
  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  bool _isVerifying = false;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _showCustomSnackBar(String message) {
    _overlayEntry?.remove();
    _overlayEntry = null;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: AnimatedSnackBar(
            message: message,
            type: "E",
            onDismissed: () {
              if (mounted) {
                _overlayEntry?.remove();
                _overlayEntry = null;
              }
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  /// Formats seconds as mm:ss (e.g. 01:05).
  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Handle OTP verification and navigate based on result.
  Future<void> _handleVerify() async {
    if (_otpController.text.length != 6) {
      _showCustomSnackBar(AppLocalizations.of(context)!.pleaseEnterAValidOtp);
      return;
    }

    setState(() => _isVerifying = true);

    final authProvider = context.read<AuthProvider>();
    await authProvider.verifyOtp(
      otp: _otpController.text,
      countryCode: widget.countryCode,
      phoneNumber: widget.phoneNumber,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (authProvider.status == AuthStatus.authenticated) {
      // ── Existing user → go straight to Home ──
      debugPrint('✅ Existing user — navigating to Home');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Home()),
        (route) => false,
      );
    } else if (authProvider.status == AuthStatus.otpVerified) {
      // ── New user → go to SignUp ──
      debugPrint('🆕 New user — navigating to SignUp');
      Navigator.of(context).push(
        SmoothNavigation.route(
          SignUpPage(
            countryCode: widget.countryCode,
            phoneNumber: widget.phoneNumber,
          ),
        ),
      );
    } else if (authProvider.status == AuthStatus.failure &&
        authProvider.errorMessage != null) {
      _showCustomSnackBar(authProvider.errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    PreferredSizeWidget buidAppBar() {
      return PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withAlpha(150), Colors.transparent],
            ),
          ),
          child: AppBar(
            centerTitle: true,
            title: Text(
              AppLocalizations.of(context)!.enterOtp,
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ),
      );
    }

    final defaultPinTheme = PinTheme(
      width: 55,
      height: 55,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E1105),
            Color(0xFF1E1105),
            Color.fromARGB(255, 26, 23, 23),
            Color.fromARGB(255, 26, 23, 23),
          ],
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.transparent,
        appBar: buidAppBar(),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 50),

              // Title
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: AppLocalizations.of(context)!.otpHasBeenSentTo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: '${widget.countryCode} ${widget.phoneNumber}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // OTP Input Fields
              Pinput(
                length: 6,
                controller: _otpController,
                focusNode: _otpFocusNode,
                defaultPinTheme: defaultPinTheme,
                obscureText: true,
                obscuringCharacter: '*',
                separatorBuilder: (index) => const SizedBox(width: 8),
                focusedPinTheme: defaultPinTheme.copyWith(
                  decoration: defaultPinTheme.decoration!.copyWith(
                    border: Border.all(color: const Color(0xFFD4A574)),
                  ),
                ),
                onCompleted: (pin) {
                  debugPrint('OTP Completed: $pin');
                },
              ),

              const SizedBox(height: 24),

              // ── Resend OTP row ──────────────────────────────────
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  final canResend = authProvider.resendCountdown == 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.didntReceiveTheCode,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha(180),
                        ),
                      ),
                      GestureDetector(
                        onTap: canResend
                            ? () async {
                                final authProvider = context
                                    .read<AuthProvider>();
                                final success = await authProvider
                                    .requestOtpResend(
                                      countryCode: widget.countryCode,
                                      phoneNumber: widget.phoneNumber,
                                    );

                                if (mounted) {
                                  if (success) {
                                    _showCustomSnackBar(
                                      "${AppLocalizations.of(context)!.otpHasBeenResentTo}${widget.countryCode} ${widget.phoneNumber}",
                                    );
                                  } else {
                                    final error = authProvider.errorMessage;
                                    final message =
                                        error ==
                                            "invalid phone number or country code"
                                        ? AppLocalizations.of(
                                            context,
                                          )!.invalidPhoneNumberOrCountryCode
                                        : (error ??
                                              AppLocalizations.of(
                                                context,
                                              )!.somethingWentWrong);
                                    _showCustomSnackBar(message);
                                  }
                                }
                              }
                            : null,
                        child: Text(
                          canResend
                              ? AppLocalizations.of(context)!.resendOtp
                              : '${AppLocalizations.of(context)!.resendIn}${_formatCountdown(authProvider.resendCountdown)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: canResend
                                ? const Color(0xFFD4A574)
                                : Colors.white.withAlpha(100),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 56),

              // Verify Button
              PremiumButton(
                showLoader: _isVerifying,
                fontsize: 18,
                text: AppLocalizations.of(context)!.verify,
                onTap: _isVerifying ? () {} : _handleVerify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
