import 'package:flutter/material.dart';
import 'package:premium_force_main/authentication/otp.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/checkbox.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/common_widgets/textfield.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';
import 'package:country_picker/country_picker.dart';

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
  OverlayEntry? _overlayEntry;
  bool _isLoading = false;
  String _selectedCountryCode = '966';

  @override
  void dispose() {
    _overlayEntry?.remove();
    _mobileController.dispose();
    _emailController.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFF1E1105),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Top section with logo
            Expanded(
              flex: 30,
              child: SizedBox(
                child: Image.asset(
                  'assets/applogo/premiumforcelogo.png', // You'll need to add your logo
                  width: 180,
                  height: 100,
                ),
              ),
            ),
            // Bottom section with form
            Expanded(
              flex: 55,
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
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 40),
                      // Sign In Title
                      Text(
                        AppLocalizations.of(context)!.signIn,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 32),

                      PremiumTextField(
                        title: AppLocalizations.of(context)!.mobileNumber,
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
                        fontsize: 16,

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
                                backgroundColor: const Color(0xFF141313),
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                searchTextStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  topRight: Radius.circular(30),
                                ),
                                inputDecoration: InputDecoration(
                                  hintText: AppLocalizations.of(
                                    context,
                                  )!.search, // Need to make sure AppLocalizations has search, if not we use a fallback or simply 'Search'. Let's see if search is there. If not, maybe use 'Search'
                                  // fallback:
                                  // hintText: 'Search',
                                  hintStyle: TextStyle(
                                    color: Colors.white.withAlpha(180),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Colors.white,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFF1A1410),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE4A46B),
                                    ),
                                  ),
                                ),
                                bottomSheetHeight:
                                    MediaQuery.of(context).size.height * 0.75,
                              ),
                              onSelect: (Country country) {
                                setState(() {
                                  _selectedCountryCode = country.phoneCode;
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
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.white,
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text:
                                        'By Clicking continue button you agree to our ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Terms and Conditions',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' and ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
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
                        fontsize: 18,
                        text: AppLocalizations.of(context)!.continueText,
                        onTap: () {
                          if (_formKey.currentState!.validate() && _isAgreed) {
                            // setState(() {
                            //   _isLoading = !_isLoading;
                            // });
                            Navigator.of(context).push(
                              SmoothNavigation.route(
                                OTPVerificationPage(
                                  countryCode: '+$_selectedCountryCode',
                                  phoneNumber: _mobileController.text.trim(),
                                ),
                              ),
                            );
                          } else if (_isAgreed == false) {
                            _showCustomSnackBar(
                              'Please agree to the terms and conditions and privacy policy.',
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
