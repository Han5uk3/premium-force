import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/authentication/signup.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';

class OTPVerificationPage extends StatefulWidget {
  final String phone;
  const OTPVerificationPage({super.key, required this.phone});

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
                      text: 'OTP has been sent to ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                    TextSpan(
                      text: widget.phone,
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

              const SizedBox(height: 80),

              // Verify Button
              PremiumButton(
                fontsize: 18,
                text: "Verify",
                onTap: () {
                  if (_otpController.text.length != 6) {
                    _showCustomSnackBar("Please enter a valid OTP");
                    return;
                  }
                  String otp = _otpController.text;
                  debugPrint('OTP Entered: $otp');
                  Navigator.of(context).push(
                    SmoothNavigation.route(
                      SignUpPage(phoneNumber: widget.phone),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
