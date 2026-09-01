import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pinput/pinput.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:premium_force_main/theme/app_palette.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/authentication/signup.dart';
import 'package:premium_force_main/home/home.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/authentication/blocked_page.dart';

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
  static const int _otpLength = 6;

  /// Matches an [_otpLength]-digit run that isn't part of a longer number, so a
  /// support line or order id in the SMS body can't be mistaken for the code.
  static const String _smsCodeMatcher = '(?<!\\d)\\d{$_otpLength}(?!\\d)';

  final TextEditingController _otpController = TextEditingController();
  final FocusNode _otpFocusNode = FocusNode();
  bool _isVerifying = false;

  /// Guards against stacking SMS User Consent listeners across resends.
  bool _isListeningForSms = false;

  @override
  void initState() {
    super.initState();
    _listenForSmsCode();
  }

  @override
  void dispose() {
    AnimatedSnackBar.dismiss();
    if (_isListeningForSms) {
      SmartAuth.instance.removeUserConsentApiListener();
    }
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  /// Android SMS autofill via the SMS User Consent API.
  ///
  /// Registers a one-shot listener; Android shows its own consent dialog when a
  /// matching SMS arrives, and only on approval do we get the message body.
  /// The listener is one-shot by design, so this is called again after a resend.
  ///
  /// iOS needs nothing here: the Pinput field advertises
  /// [AutofillHints.oneTimeCode] inside an [AutofillGroup], which is what drives
  /// the QuickType "From Messages" suggestion above the keyboard.
  Future<void> _listenForSmsCode() async {
    if (!Platform.isAndroid || _isListeningForSms) return;

    _isListeningForSms = true;
    final res = await SmartAuth.instance.getSmsWithUserConsentApi(
      matcher: _smsCodeMatcher,
    );
    _isListeningForSms = false;

    // The page may have been popped while we were waiting on the user, which
    // would leave _otpController disposed.
    if (!mounted) return;

    final code = res.hasData ? res.requireData.code : null;
    if (code == null || code.length != _otpLength) return;

    // Triggers Pinput's onCompleted, which runs the verify action.
    _otpController.setText(code);
  }

  void _showCustomSnackBar(String message, [String type = 'E']) {
    AnimatedSnackBar.show(context, message, type);
  }

  /// Formats seconds as mm:ss (e.g. 01:05).
  String _formatCountdown(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Handle OTP verification and navigate based on result.
  Future<void> _handleVerify() async {
    if (_isVerifying) return;

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
      // â”€â”€ Existing user â†’ check if active â”€â”€
      if (authProvider.user?.isActive ?? true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => Home()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const BlockedPage()),
          (route) => false,
        );
      }
    } else if (authProvider.status == AuthStatus.otpVerified) {
      // â”€â”€ New user â†’ go to SignUp â”€â”€
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
    final c = context.colors;
    PreferredSizeWidget buidAppBar() {
      return PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: c.appBarScrim,
            ),
          ),
          child: AppBar(
            centerTitle: true,
            title: Text(
              AppLocalizations.of(context)!.enterOtp,
              style: TextStyle(
                fontSize: 18,
                color: c.textPrimary,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, size: 16, color: c.icon),
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
      textStyle: TextStyle(
        fontSize: 20,
        color: c.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: c.mainColor,
        borderRadius: BorderRadius.circular(12),
        // Matches the fill, so an unfocused box reads as borderless while the
        // focused theme below still has an edge to draw on.
        border: Border.all(color: c.border),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: c.pageGradient,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: c.textSecondary,
                      ),
                    ),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          '${widget.countryCode} ${widget.phoneNumber}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // OTP Input Fields
              Directionality(
                textDirection: TextDirection.ltr,
                child: AutofillGroup(
                  // Ensures the OS-level "code from Messages" autofill
                  // suggestion reliably appears for this field.
                  child: Pinput(
                    length: 6,
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    defaultPinTheme: defaultPinTheme,
                    obscureText: true,
                    obscuringCharacter: '*',
                    enableInteractiveSelection: true,
                    showCursor: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    contextMenuBuilder: (context, editableTextState) {
                      final List<ContextMenuButtonItem> buttonItems = [
                        ContextMenuButtonItem(
                          onPressed: () {
                            editableTextState.pasteText(
                              SelectionChangedCause.toolbar,
                            );
                          },
                          type: ContextMenuButtonType.paste,
                        ),
                      ];

                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: editableTextState.contextMenuAnchors,
                        buttonItems: buttonItems,
                      );
                    },
                    separatorBuilder: (index) => const SizedBox(width: 8),
                    focusedPinTheme: defaultPinTheme.copyWith(
                      decoration: defaultPinTheme.decoration!.copyWith(
                        border: Border.all(color: c.accent),
                      ),
                    ),
                    onCompleted: (pin) {
                      // All 6 digits entered: run the same action as the
                      // Verify button.
                      _otpFocusNode.unfocus();
                      _handleVerify();
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // â”€â”€ Resend OTP row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Consumer<AuthProvider>(
                builder: (context, authProvider, child) {
                  final canResend = authProvider.resendCountdown == 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.didntReceiveTheCode,
                        style: TextStyle(fontSize: 12, color: c.textTertiary),
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
                                    // The previous listener was consumed by the
                                    // first OTP, so re-arm it for this one.
                                    _listenForSmsCode();
                                    _showCustomSnackBar(
                                      "${AppLocalizations.of(context)!.otpHasBeenResentTo}${widget.countryCode} ${widget.phoneNumber}",
                                      'S',
                                    );
                                  } else {
                                    final error = authProvider.errorMessage;
                                    final isInvalidPhone =
                                        error ==
                                            "invalid phone number or country code" ||
                                        error ==
                                            "please check entered phone number";
                                    final message = isInvalidPhone
                                        ? AppLocalizations.of(
                                            context,
                                          )!.pleaseCheckEnteredPhoneNumber
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
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: canResend ? c.accent : c.textDisabled,
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
                fontsize: 16,
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
