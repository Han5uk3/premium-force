import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pinput/pinput.dart';
import 'package:premium_force_main/bloc/auth/auth_bloc.dart';
import 'package:premium_force_main/bloc/auth/auth_event.dart';
import 'package:premium_force_main/bloc/auth/auth_state.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/authentication/signup.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';

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
              "Enter OTP",
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

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.otpVerified) {
          Navigator.of(context).push(
            SmoothNavigation.route(
              SignUpPage(
                countryCode: widget.countryCode,
                phoneNumber: widget.phoneNumber,
              ),
            ),
          );
        } else if (state.status == AuthStatus.failure &&
            state.errorMessage != null) {
          _showCustomSnackBar(state.errorMessage!);
        }
      },
      child: Container(
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
                        text: 'OTP has been sent to ',
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
                BlocBuilder<AuthBloc, AuthState>(
                  buildWhen: (prev, curr) =>
                      prev.resendCountdown != curr.resendCountdown,
                  builder: (context, state) {
                    final canResend = state.resendCountdown == 0;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the code? ",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withAlpha(180),
                          ),
                        ),
                        GestureDetector(
                          onTap: canResend
                              ? () {
                                  context.read<AuthBloc>().add(
                                    AuthOtpResendRequested(
                                      countryCode: widget.countryCode,
                                      phoneNumber: widget.phoneNumber,
                                    ),
                                  );
                                  _showCustomSnackBar(
                                    "OTP has been resent to ${widget.countryCode} ${widget.phoneNumber}",
                                  );
                                }
                              : null,
                          child: Text(
                            canResend
                                ? 'Resend OTP'
                                : 'Resend in ${_formatCountdown(state.resendCountdown)}',
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
                  showLoader: false,
                  fontsize: 18,
                  text: "Verify",
                  onTap: () {
                    if (_otpController.text.length != 6) {
                      _showCustomSnackBar("Please enter a valid OTP");
                      return;
                    }
                    String otp = _otpController.text;
                    debugPrint('OTP Entered: $otp');
                    context.read<AuthBloc>().add(
                      AuthOtpVerified(
                        otp: otp,
                        countryCode: widget.countryCode,
                        phoneNumber: widget.phoneNumber,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
