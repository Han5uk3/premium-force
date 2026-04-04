import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:premium_force_main/api/apis.dart';
import 'package:premium_force_main/authentication/location_picker.dart';
import 'package:premium_force_main/common_widgets/button.dart';
import 'package:premium_force_main/common_widgets/premiumloader.dart';
import 'package:premium_force_main/common_widgets/textfield.dart';
import 'package:premium_force_main/common_widgets/snackbar.dart';
import 'package:premium_force_main/home/home.dart';
import 'package:premium_force_main/l10n/app_localizations.dart';
import 'package:premium_force_main/storage/user_local_storage.dart';
import 'package:premium_force_main/utils/smooth_navigation.dart';
import 'package:country_picker/country_picker.dart';
import 'package:provider/provider.dart';
import 'package:premium_force_main/providers/auth_provider.dart';


class SignUpPage extends StatefulWidget {
  final String countryCode;
  final String phoneNumber;
  final String? googleEmail;
  final String? googleDisplayName;
  final String? googlePhotoUrl;
  final String? appleEmail;
  final String? appleDisplayName;
  const SignUpPage({
    super.key,
    required this.countryCode,
    required this.phoneNumber,
    this.googleEmail,
    this.googleDisplayName,
    this.googlePhotoUrl,
    this.appleEmail,
    this.appleDisplayName,
  });

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _specialIdController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  File? _profileImage;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  bool _isCorporateEmployee = false; // New: track corporate employee checkbox
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  // Country code management
  String _selectedCountryCode = '966'; // Default to Saudi Arabia
  bool _isGoogleSignUp = false; // Track if this is from Google Sign-In
  bool _isCheckingPromo = false;
  bool _isPromoValid = false;
  String? _appliedPromoId;

  @override
  void initState() {
    super.initState();

    // Determine if this is from social sign-in (Google or Apple)
    _isGoogleSignUp =
        (widget.googleEmail != null && widget.googleEmail!.isNotEmpty) ||
        (widget.appleEmail != null && widget.appleEmail!.isNotEmpty);

    // Set initial country code
    _selectedCountryCode = widget.countryCode.replaceAll('+', '');

    _phoneController.text = widget.phoneNumber;

    // Pre-fill from sign-in data (Google or Apple)
    if (widget.googleDisplayName != null &&
        widget.googleDisplayName!.isNotEmpty) {
      _nameController.text = widget.googleDisplayName!;
    } else if (widget.appleDisplayName != null &&
        widget.appleDisplayName!.isNotEmpty) {
      _nameController.text = widget.appleDisplayName!;
    }

    if (widget.googleEmail != null && widget.googleEmail!.isNotEmpty) {
      _emailController.text = widget.googleEmail!;
    } else if (widget.appleEmail != null && widget.appleEmail!.isNotEmpty) {
      _emailController.text = widget.appleEmail!;
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutQuart,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    AnimatedSnackBar.dismiss();
    _nameController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    _specialIdController.dispose();
    _phoneController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _showCustomSnackBar(String message, {String type = "E"}) {
    AnimatedSnackBar.show(context, message, type);
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3E230A), Color(0xFF141313)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    loc.chooseProfilePicture,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImageSourceOption(
                        icon: Icons.camera_alt_rounded,
                        label: loc.camera,
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.camera,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setState(() {
                              _profileImage = File(image.path);
                            });
                          }
                        },
                      ),
                      _buildImageSourceOption(
                        icon: Icons.photo_library_rounded,
                        label: loc.gallery,
                        onTap: () async {
                          Navigator.pop(context);
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 800,
                            maxHeight: 800,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setState(() {
                              _profileImage = File(image.path);
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF49280B),
                  Color(0xFFE4A46B),
                  Color(0xFF60350F),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0A08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: const Color(0xFFE4A46B), size: 30),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(
      context,
    ).push(SmoothNavigation.route(const LocationPickerPage()));

    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _locationController.text = result['address'] ?? '';
        _latitude = result['lat'] as double?;
        _longitude = result['lng'] as double?;
      });
    }
  }

  Future<void> _verifyPromoCode() async {
    final code = _specialIdController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isCheckingPromo = true;
      _isPromoValid = false;
      _appliedPromoId = null;
    });

    final result = await ApiService().getSpecialContentByCode(code: code);

    if (result['success'] == true) {
      final promo = result['data'];
      if (promo != null && promo['isActive'] == true) {
        setState(() {
          _isPromoValid = true;
          _appliedPromoId = promo['_id'] ?? promo['id'];
        });
        if (mounted) {
          _showCustomSnackBar(
            AppLocalizations.of(context)!.promoCodeAppliedSuccessfully,
            type: "S",
          );
        }
      } else {
        setState(() {
          _isPromoValid = false;
          _appliedPromoId = null;
        });
        if (mounted) {
          _showCustomSnackBar(
            promo != null && promo['isActive'] == false
                ? AppLocalizations.of(context)!.promoCodeIsInactive
                : AppLocalizations.of(context)!.invalidPromoCode,
            type: "E",
          );
        }
      }
    } else {
      if (mounted) {
        _showCustomSnackBar(
          result['message'] ??
              AppLocalizations.of(context)!.invalidOrInactivePromoCode,
          type: "E",
        );
      }
    }

    setState(() => _isCheckingPromo = false);
  }

  void _removePromoCode() {
    setState(() {
      _isPromoValid = false;
      _appliedPromoId = null;
      _specialIdController.clear();
    });
    _showCustomSnackBar(
      AppLocalizations.of(context)!.promoCodeRemoved,
      type: "W",
    );
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    // Profile image is now optional


    if (_locationController.text.isEmpty) {
      _showCustomSnackBar(
        AppLocalizations.of(context)!.pleaseSelectYourLocation,
        type: "E",
      );
      return;
    }

    setState(() => _isLoading = true);

    final phoneNumber = _phoneController.text.trim();
    final countryCode = '+$_selectedCountryCode';

    // Only include special ID if corporate employee is checked and promo is valid
    final specialId = (_isCorporateEmployee && _isPromoValid)
        ? _specialIdController.text.trim()
        : null;

    // Delegate everything to AuthProvider.submitSignUp() which handles:
    // - API call to createUser
    // - Token extraction and saving
    // - Fetching full user profile from backend (getUserById)
    // - Setting AuthProvider._user and notifying listeners
    // - Saving user data + credentials to local storage
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.submitSignUp(
      username: _nameController.text.trim(),
      email: _emailController.text.trim(),
      countryCode: countryCode,
      phoneNumber: phoneNumber,
      location: _locationController.text.trim(),
      lat: _latitude,
      long: _longitude,
      profileImage: _profileImage,
      specialId: specialId,
    );

    if (!mounted) return;

    if (result['success'] == true) {
      // If promo was used, increment its count
      if (_isPromoValid && _appliedPromoId != null) {
        final token = UserLocalStorage.getToken();
        await ApiService().incrementSpecialContentCount(
          id: _appliedPromoId!,
          token: token,
        );
      }

      debugPrint(
        '✅ Signup │ Navigating to Home with user: ${auth.user?.username}',
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => Home()),
        (route) => false,
      );
    } else {
      _showCustomSnackBar(
        result['message'] as String? ??
            AppLocalizations.of(context)!.signupFailed,
        type: "E",
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: Colors.transparent,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: _isLoading,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),

                        // Profile Picture
                        Center(
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              children: [
                                // Gradient border
                                Container(
                                  width: 116,
                                  height: 116,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF49280B),
                                        Color(0xFFE4A46B),
                                        Color(0xFF60350F),
                                      ],
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 112,
                                      height: 112,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: const Color(0xFF0D0A08),
                                      ),
                                      child: _profileImage != null
                                          ? ClipOval(
                                              child: Image.file(
                                                _profileImage!,
                                                width: 112,
                                                height: 112,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : Center(
                                              child: ShaderMask(
                                                shaderCallback: (Rect bounds) {
                                                  return const LinearGradient(
                                                    colors: [
                                                      Color(0xFF49280B),
                                                      Color(0xFFE4A46B),
                                                      Color(0xFF60350F),
                                                    ],
                                                  ).createShader(bounds);
                                                },
                                                child: const Icon(
                                                  Icons.person_rounded,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                // Camera edit icon
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF49280B),
                                          Color(0xFFE4A46B),
                                          Color(0xFF60350F),
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(100),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.black,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            AppLocalizations.of(context)!.tapToAddPhotoOptional,
                            style: TextStyle(
                              color: Colors.white.withAlpha(100),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Name field
                        PremiumTextField(
                          title: AppLocalizations.of(context)!.fullName,
                          controller: _nameController,
                          hintText: AppLocalizations.of(
                            context,
                          )!.enterYourFullName,
                          fontsize: 13,
                          keyboardType: TextInputType.name,
                          needTitle: true,
                          obscureText: false,
                          prefixIcon: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return const LinearGradient(
                                colors: [
                                  Color(0xFF49280B),
                                  Color(0xFFE4A46B),
                                  Color(0xFF60350F),
                                ],
                              ).createShader(bounds);
                            },
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(
                                context,
                              )!.pleaseEnterYourName;
                            }
                            if (value.length < 2) {
                              return AppLocalizations.of(
                                context,
                              )!.nameMustBeAtLeast2Characters;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Phone number (editable with country code picker)
                        PremiumTextField(
                          title: AppLocalizations.of(context)!.phoneNumber,
                          controller: _phoneController,
                          hintText: AppLocalizations.of(
                            context,
                          )!.enterMobileNumber,
                          fontsize: 13,
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
                                    fontSize: 14,
                                  ),
                                  searchTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(30),
                                    topRight: Radius.circular(30),
                                  ),
                                  inputDecoration: InputDecoration(
                                    hintText: AppLocalizations.of(
                                      context,
                                    )!.search,
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
                          validator: (value) {
                            if (value == null || value.isEmpty) {
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
                        ),

                        const SizedBox(height: 20),

                        // Email field (non-editable if from Google Sign-In, editable otherwise)
                        PremiumTextField(
                          title: AppLocalizations.of(context)!.emailAddress,
                          controller: _emailController,
                          hintText: AppLocalizations.of(
                            context,
                          )!.enterYourEmailAddress,
                          fontsize: 13,
                          keyboardType: TextInputType.emailAddress,
                          needTitle: true,
                          obscureText: false,
                          enabled:
                              !_isGoogleSignUp, // Disable if from Google Sign-In
                          readOnly:
                              _isGoogleSignUp, // Read-only if from Google Sign-In
                          prefixIcon: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return const LinearGradient(
                                colors: [
                                  Color(0xFF49280B),
                                  Color(0xFFE4A46B),
                                  Color(0xFF60350F),
                                ],
                              ).createShader(bounds);
                            },
                            child: const Icon(
                              Icons.email_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return AppLocalizations.of(
                                context,
                              )!.pleaseEnterYourEmail;
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return AppLocalizations.of(
                                context,
                              )!.pleaseEnterAValidEmail;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Location field (tap to open location picker)
                        _buildLocationField(),

                        const SizedBox(height: 20),

                        // Corporate Employee Checkbox
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withAlpha(60),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFF0D0A08),
                          ),
                          child: Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isCorporateEmployee =
                                        !_isCorporateEmployee;
                                  });
                                },
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _isCorporateEmployee
                                          ? const Color(0xFFE4A46B)
                                          : Colors.white.withAlpha(100),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    color: _isCorporateEmployee
                                        ? const Color(0xFFE4A46B)
                                        : Colors.transparent,
                                  ),
                                  child: _isCorporateEmployee
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Color(0xFF0D0A08),
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.iAmACorporateEmployee,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_isCorporateEmployee) ...[
                          const SizedBox(height: 20),
                          // Special ID (optional)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                flex: 3,
                                child: PremiumTextField(
                                  title:
                                      AppLocalizations.of(context)!.promoCode,
                                  controller: _specialIdController,
                                  hintText: AppLocalizations.of(
                                    context,
                                  )!.enterYourPromoCode,
                                  fontsize: 13,
                                  needTitle: true,
                                  obscureText: false,
                                  readOnly: _isPromoValid, // Lock if valid
                                  enabled: !_isPromoValid, // Lock if valid
                                  prefixIcon: ShaderMask(
                                    shaderCallback: (Rect bounds) {
                                      return const LinearGradient(
                                        colors: [
                                          Color(0xFF49280B),
                                          Color(0xFFE4A46B),
                                          Color(0xFF60350F),
                                        ],
                                      ).createShader(bounds);
                                    },
                                    child: const Icon(
                                      Icons.badge_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (_isCorporateEmployee &&
                                        (value == null || value.isEmpty)) {
                                      return AppLocalizations.of(
                                        context,
                                      )!.pleaseEnterYourPromoCode;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 1,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 0),
                                  child: SizedBox(
                                    height: 59,
                                    child: PremiumButton(
                                      showLoader: _isCheckingPromo,
                                      fontsize: 12,
                                      text: _isPromoValid
                                          ? AppLocalizations.of(context)!.remove
                                          : AppLocalizations.of(context)!.apply,
                                      gradient: _isPromoValid
                                          ? [
                                            Colors.red.shade800,
                                            Colors.red.shade400,
                                          ]
                                          : null,
                                      onTap: _isCheckingPromo
                                          ? () {}
                                          : _isPromoValid
                                              ? _removePromoCode
                                              : _verifyPromoCode,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 36),

                        // Sign Up button
                        PremiumButton(
                          showLoader: _isLoading,
                          fontsize: 16,
                          text: AppLocalizations.of(context)!.createAccount,
                          onTap: _isLoading ? () {} : _handleSignUp,
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Loading overlay
            if (_isLoading) const PremiumLoaderOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context)!.location,
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openLocationPicker,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0A08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1A1410), width: 1),
            ),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      colors: [
                        Color(0xFF49280B),
                        Color(0xFFE4A46B),
                        Color(0xFF60350F),
                      ],
                    ).createShader(bounds);
                  },
                  child: const Icon(
                    Icons.location_on_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _locationController.text.isEmpty
                        ? AppLocalizations.of(context)!.tapToSelectYourLocation
                        : _locationController.text,
                    style: TextStyle(
                      color: _locationController.text.isEmpty
                          ? Colors.white.withAlpha(180)
                          : Colors.white,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      colors: [
                        Color(0xFF49280B),
                        Color(0xFFE4A46B),
                        Color(0xFF60350F),
                      ],
                    ).createShader(bounds);
                  },
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
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
            AppLocalizations.of(context)!.createAccount,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }
}

