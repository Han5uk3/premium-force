import 'package:flutter/material.dart';
import 'package:premium_force_main/authentication/otp.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/checkbox.dart';
import 'package:premium_force_main/common_widgets/textfield.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';

class PremiumForceLoginPage extends StatefulWidget {
  const PremiumForceLoginPage({super.key});

  @override
  State<PremiumForceLoginPage> createState() => _PremiumForceLoginPageState();
}

final _formKey = GlobalKey<FormState>();

class _PremiumForceLoginPageState extends State<PremiumForceLoginPage> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _isAgreed = true;

  @override
  void dispose() {
    _mobileController.dispose();
    _emailController.dispose();
    super.dispose();
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
                        needCountryCode: true,
                        fontsize: 16,
                        
                        keyboardType: TextInputType.phone,
                        needTitle: true,
                        obscureText: false,
                        maxLength: 9,
                      ),

                      const SizedBox(height: 24),

                      // Continue Button
                      PremiumButton(
                        fontsize: 18,
                        text: AppLocalizations.of(context)!.continueText,
                        onTap: () {
                          if (_formKey.currentState!.validate() && _isAgreed) {
                            Navigator.of(context).push(
                              SmoothNavigation.route(
                                OTPVerificationPage(
                                  phone: "+966${_mobileController.text.trim()}",
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: Colors.red,
                                content: Text(
                                  'Please agree to the terms and conditions and privacy policy.',
                                ),
                              ),
                            );
                          }
                        },
                      ),
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
