import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:premium_force_main/main.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_main/authentication/otp.dart';
import 'package:premium_force_main/authentication/signup.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/checkbox.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/common_widgets/textfield.dart';
import 'package:premium_force_main/home/home.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/providers/auth_provider.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';
import 'package:country_picker/country_picker.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';

class PremiumForceLoginPage extends StatefulWidget {
  const PremiumForceLoginPage({super.key});

  @override
  State<PremiumForceLoginPage> createState() => _PremiumForceLoginPageState();
}

final _formKey = GlobalKey<FormState>();

class _PremiumForceLoginPageState extends State<PremiumForceLoginPage> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isAgreed = false;
  bool _isLoading = false;
  final FocusNode _mobileFocusNode = FocusNode();
  String _selectedCountryCode = '966';

  @override
  void initState() {
    super.initState();
    _mobileFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    AnimatedSnackBar.dismiss();
    _mobileController.dispose();
    _emailController.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  void _showCustomSnackBar(String message, [String type = 'E']) {
    AnimatedSnackBar.show(context, message, type);
  }

  /// Handle Google Sign-In button tap.
  Future<void> _handleGoogleSignIn() async {
    if (!_isAgreed) {
      _showCustomSnackBar(
        AppLocalizations.of(
          context,
        )!.pleaseAgreeToTheTermsAndConditionsAndPrivacyPolicy,
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await authProvider.signInWithGoogle();

    if (!mounted) return;

    if (authProvider.status == AuthStatus.authenticated) {
      // Existing user â€” go to home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Home()),
        (route) => false,
      );
    } else if (authProvider.status == AuthStatus.otpVerified) {
      // New user â€” go to signup with pre-filled data
      final googleResult = authProvider.googleResult;
      Navigator.of(context).push(
        SmoothNavigation.route(
          SignUpPage(
            countryCode: '+$_selectedCountryCode',
            phoneNumber: '',
            googleEmail: googleResult?.email,
            googleDisplayName: googleResult?.displayName,
            googlePhotoUrl: googleResult?.photoUrl,
          ),
        ),
      );
    } else if (authProvider.status == AuthStatus.failure &&
        authProvider.errorMessage != null) {
      _showCustomSnackBar(authProvider.errorMessage!);
    }
  }

  /// Handle Apple Sign-In button tap.
  Future<void> _handleAppleSignIn() async {
    if (!_isAgreed) {
      _showCustomSnackBar(
        AppLocalizations.of(
          context,
        )!.pleaseAgreeToTheTermsAndConditionsAndPrivacyPolicy,
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    await authProvider.signInWithApple();

    if (!mounted) return;

    if (authProvider.status == AuthStatus.authenticated) {
      // Existing user â€” go to home
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Home()),
        (route) => false,
      );
    } else if (authProvider.status == AuthStatus.otpVerified) {
      // New user â€” go to signup with pre-filled data
      final appleResult = authProvider.appleResult;
      Navigator.of(context).push(
        SmoothNavigation.route(
          SignUpPage(
            countryCode: '+$_selectedCountryCode',
            phoneNumber: '',
            appleEmail: appleResult?.email,
            appleDisplayName: appleResult?.displayName,
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
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF1E1105),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final bool isAnyLoading =
              _isLoading ||
              authProvider.isGoogleLoading ||
              authProvider.isAppleLoading;

          return AbsorbPointer(
            absorbing: isAnyLoading,
            child: Form(
              key: _formKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double bottomInset = MediaQuery.of(
                    context,
                  ).viewInsets.bottom;
                  final double screenHeight = constraints.maxHeight;
                  final double initialFormTop = screenHeight * 0.35;

                  // Sync settings
                  const Duration animDuration = Duration(milliseconds: 250);
                  const Curve animCurve = Curves.easeOutCubic;

                  // Movements
                  // Only slide the background if the login screen's own field has focus
                  final bool isMainKeyboardActive = _mobileFocusNode.hasFocus;

                  // Logo moves up subtly (by 30% of keyboard)
                  final double logoSlideUp = isMainKeyboardActive
                      ? (bottomInset * 0.30)
                      : 0;
                  // Form slides over the logo (by 60% of keyboard)
                  // Capped to ensure some logo area always remains visible
                  final double maxFormSlide =
                      initialFormTop - 60; // Leave 60px of top area
                  final double formSlideUp = isMainKeyboardActive
                      ? (bottomInset * 0.65).clamp(0, maxFormSlide)
                      : 0;

                  return Stack(
                    children: [
                      // Logo Parallax
                      AnimatedPositioned(
                        duration: animDuration,
                        curve: animCurve,
                        top: -logoSlideUp,
                        left: 0,
                        right: 0,
                        height: initialFormTop,
                        child: Center(
                          child: Image.asset(
                            'assets/applogo/premiumforcelogo.png',
                            width: 200,
                            height: 100,
                          ),
                        ),
                      ),
                      // Form Slide
                      AnimatedPositioned(
                        duration: animDuration,
                        curve: animCurve,
                        top: initialFormTop - formSlideUp,
                        left: 0,
                        right: 0,
                        bottom: -formSlideUp,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF3E230A), Color(0xFF141313)],
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: SingleChildScrollView(
                              padding: EdgeInsets.only(
                                bottom: bottomInset > 0 ? bottomInset + 20 : 0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 20),
                                  // Sign In Title
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        AppLocalizations.of(context)!.signIn,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      CircleAvatar(
                                        radius: 16,
                                        child: Material(
                                          borderRadius: BorderRadius.circular(
                                            100,
                                          ),

                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              100,
                                            ),
                                            child: InkWell(
                                              splashColor: Colors.grey
                                                  .withAlpha(200),
                                              borderRadius:
                                                  BorderRadius.circular(100),
                                              onTap: () {
                                                bool isCurrentlyEnglish =
                                                    Localizations.localeOf(
                                                      context,
                                                    ).languageCode ==
                                                    'en';
                                                MainApp.setLocale(
                                                  context,
                                                  Locale(
                                                    isCurrentlyEnglish
                                                        ? 'ar'
                                                        : 'en',
                                                  ),
                                                );
                                              },
                                              child: SvgPicture.asset(
                                                Localizations.localeOf(
                                                          context,
                                                        ).languageCode ==
                                                        'en'
                                                    ? 'assets/flags/en.svg'
                                                    : 'assets/flags/ar.svg',
                                                fit: BoxFit.fill,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),

                                  PremiumTextField(
                                    focusNode: _mobileFocusNode,
                                    title: AppLocalizations.of(
                                      context,
                                    )!.mobileNumber,
                                    validator: (value) {
                                      if (value!.isEmpty) {
                                        return AppLocalizations.of(
                                          context,
                                        )!.pleaseEnterYourMobileNumber;
                                      }
                                      if (value.length < 9) {
                                        return AppLocalizations.of(
                                          context,
                                        )!.pleaseEnterValidMobileNumber;
                                      }
                                      return null;
                                    },
                                    controller: _mobileController,
                                    hintText: AppLocalizations.of(
                                      context,
                                    )!.enterMobileNumber,
                                    fontsize: 14,

                                    keyboardType: TextInputType.phone,
                                    needTitle: true,
                                    obscureText: false,
                                    prefixIcon: GestureDetector(
                                      onTap: () {
                                        showCountryPicker(
                                          context: context,
                                          showPhoneCode: true,
                                          customFlagBuilder: (context) =>
                                              const SizedBox.shrink(),
                                          countryListTheme: CountryListThemeData(
                                            backgroundColor: const Color(
                                              0xFF141313,
                                            ),
                                            textStyle: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                            searchTextStyle: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                            ),
                                            borderRadius:
                                                const BorderRadius.only(
                                                  topLeft: Radius.circular(30),
                                                  topRight: Radius.circular(30),
                                                ),
                                            inputDecoration: InputDecoration(
                                              hintText: AppLocalizations.of(
                                                context,
                                              )!.search,
                                              hintStyle: TextStyle(
                                                color: Colors.white.withAlpha(
                                                  180,
                                                ),
                                              ),
                                              prefixIcon: const Icon(
                                                Icons.search,
                                                color: Colors.white,
                                              ),
                                              filled: true,
                                              fillColor: const Color(
                                                0xFF1A1410,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: BorderSide(
                                                  color: Colors.grey.shade800,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE4A46B),
                                                ),
                                              ),
                                            ),
                                            bottomSheetHeight:
                                                MediaQuery.of(
                                                  context,
                                                ).size.height *
                                                0.75,
                                          ),
                                          onSelect: (Country country) {
                                            setState(() {
                                              _selectedCountryCode =
                                                  country.phoneCode;
                                            });
                                          },
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: const BoxDecoration(
                                          color: Colors.transparent,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '+$_selectedCountryCode',
                                              textDirection: TextDirection.ltr,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const Icon(
                                              Icons.arrow_drop_down,
                                              color: Colors.white,
                                            ),
                                            Container(
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              height: 24,
                                              width: 1,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Continue Button
                                  const SizedBox(height: 20),
                                  // Terms and Conditions
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      PremiumCheckbox(
                                        ontap: () {
                                          setState(() {
                                            _isAgreed = !_isAgreed;
                                          });
                                        },
                                        isAgreed: _isAgreed,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              color: Color(0xFFB0B0B0),
                                              fontSize: 11,
                                              height: 1.4,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: AppLocalizations.of(
                                                  context,
                                                )!.byClickingContinueButton,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    " ${AppLocalizations.of(context)!.termsAndConditions}",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                              TextSpan(
                                                text:
                                                    " ${AppLocalizations.of(context)!.and} ",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                              TextSpan(
                                                text: AppLocalizations.of(
                                                  context,
                                                )!.privacyPolicy,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  decoration:
                                                      TextDecoration.none,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 25),
                                  PremiumButton(
                                    showLoader: _isLoading,
                                    fontsize: 16,
                                    text: AppLocalizations.of(
                                      context,
                                    )!.continueText,
                                    onTap: () async {
                                      if (_formKey.currentState!.validate() &&
                                          _isAgreed) {
                                        setState(() => _isLoading = true);

                                        final authProvider = context
                                            .read<AuthProvider>();
                                        final success = await authProvider
                                            .requestOtp(
                                              countryCode:
                                                  '+$_selectedCountryCode',
                                              phoneNumber: _mobileController
                                                  .text
                                                  .trim(),
                                            );

                                        if (!mounted) return;
                                        setState(() => _isLoading = false);

                                        if (success) {
                                          Navigator.of(context).push(
                                            SmoothNavigation.route(
                                              OTPVerificationPage(
                                                countryCode:
                                                    '+$_selectedCountryCode',
                                                phoneNumber: _mobileController
                                                    .text
                                                    .trim(),
                                              ),
                                            ),
                                          );
                                        } else {
                                          final error =
                                              authProvider.errorMessage;
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
                                      } else if (_isAgreed == false) {
                                        _showCustomSnackBar(
                                          AppLocalizations.of(
                                            context,
                                          )!.pleaseAgreeToTheTermsAndConditionsAndPrivacyPolicy,
                                        );
                                      }
                                    },
                                  ),

                                  const SizedBox(height: 24),

                                  // â”€â”€ OR divider â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 1,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                Colors.white.withAlpha(60),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        child: Text(
                                          AppLocalizations.of(context)!.or,
                                          style: TextStyle(
                                            color: Colors.white.withAlpha(150),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Container(
                                          height: 1,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white.withAlpha(60),
                                                Colors.transparent,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // â”€â”€ Google Sign-In button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                                  _GoogleSignInButton(
                                    isLoading: authProvider.isGoogleLoading,
                                    onTap: _handleGoogleSignIn,
                                  ),

                                  if (!Platform.isAndroid) ...[
                                    const SizedBox(height: 12),

                                    // â”€â”€ Apple Sign-In button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                                    _AppleSignInButton(
                                      isLoading: authProvider.isAppleLoading,
                                      onTap: _handleAppleSignIn,
                                    ),
                                  ],

                                  const SizedBox(height: 32),
                                ],
                              ), // Column
                            ), // SingleChildScrollView
                          ), // Padding
                        ), // Container
                      ), // AnimatedPositioned
                    ], // Children
                  ); // Stack
                }, // Builder
              ), // LayoutBuilder
            ),
          );
        },
      ), // Form
    ); // Scaffold body (actually Form is the body)
  }
}

/// A styled Google Sign-In button that matches the app's dark premium theme.
class _GoogleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _GoogleSignInButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(40), width: 1),
        color: const Color(0xFF0D0A08),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withAlpha(20),
          highlightColor: Colors.white.withAlpha(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const PremiumLoader(size: 24, color: Color(0xFFE4A46B))
                else ...[
                  SvgPicture.asset(
                    'assets/icons/google_logo.svg',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    AppLocalizations.of(context)!.continueWithGoogle,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A styled Apple Sign-In button that matches the app's dark premium theme.
class _AppleSignInButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _AppleSignInButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(40), width: 1),
        color: const Color(0xFF0D0A08),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withAlpha(20),
          highlightColor: Colors.white.withAlpha(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const PremiumLoader(size: 24, color: Color(0xFFE4A46B))
                else ...[
                  const Icon(Icons.apple, color: Colors.white, size: 24),
                  const SizedBox(width: 14),
                  Text(
                    AppLocalizations.of(context)!.continueWithApple,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
